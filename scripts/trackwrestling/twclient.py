"""twclient.py — Trackwrestling HTTP client: session bootstrap + polite cached fetch.

LEGAL / POLITENESS NOTICE
-------------------------
- Respect trackwrestling.com's terms of service, robots guidance, and access
  controls. Use this client only for data you are authorized to collect.
- Do NOT attempt to bypass CAPTCHAs, authentication, or any access control.
- Request rates are deliberately low (>= 1.0s delay + jitter between requests)
  and every page is cached on disk so the same URL is never fetched twice
  unless --refresh is explicitly requested.
- Never commit USER_SESSIONID cookies or twSessionId tokens to git.

Request shape (per trackwrestling_scraping_notes.md):

    GET https://www.trackwrestling.com/seasons/EventMatches.jsp
        ?TIM=<unix ms>&twSessionId=<token>&seasonId=..&eventId=..&teamId=..

Session bootstrap: GET a legitimate season entry page first so the server
issues a USER_SESSIONID cookie, then scrape `twSessionId` out of the HTML.
"""

from __future__ import annotations

import hashlib
import json
import os
import random
import re
import time
from pathlib import Path

import requests

BASE_URL = "https://www.trackwrestling.com/seasons"
EVENT_MATCHES_URL = f"{BASE_URL}/EventMatches.jsp"

DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0 Safari/537.36"
)

# twSessionId appears in links (...&twSessionId=abc123...) and inline scripts
# (var twSessionId = "abc123"; / twSessionId: 'abc123').
TW_SESSION_RE = re.compile(r"twSessionId['\"]?\s*[:=]\s*['\"]?([\w-]+)")

MIN_RESPONSE_BYTES = 1000
SESSION_GUIDANCE = (
    "Trackwrestling rejected the request (session expired or not accepted). "
    "Fix: browse to the season page in a real browser (e.g. "
    "https://www.trackwrestling.com/seasons/TWHome.jsp?seasonId=<SEASON>), "
    "open any EventMatches team link, copy the twSessionId query parameter, "
    "then re-run with TW_SESSION_ID=<value> in the environment or "
    "--tw-session-id / TWClient(tw_session_id=...)."
)


class SessionExpired(RuntimeError):
    """Raised when the site refuses EventMatches requests (406, redirect, or
    truncated response) even after one re-bootstrap attempt."""


class RequestCapExceeded(RuntimeError):
    """Raised when the per-run request budget (--max-requests) is exhausted."""


# --------------------------------------------------------------------------
# Cache helpers (module level so parse tooling can use them without a client)
# --------------------------------------------------------------------------

def cache_key(season_id: str, event_id: str, team_id: str) -> str:
    return hashlib.sha256(f"{season_id}|{event_id}|{team_id}".encode()).hexdigest()


def cache_file(cache_dir: str | Path, key: str) -> Path:
    return Path(cache_dir) / f"{key}.html"


def _index_path(cache_dir: str | Path) -> Path:
    return Path(cache_dir) / "index.json"


def load_index(cache_dir: str | Path) -> dict:
    path = _index_path(cache_dir)
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def save_index(cache_dir: str | Path, index: dict) -> None:
    Path(cache_dir).mkdir(parents=True, exist_ok=True)
    _index_path(cache_dir).write_text(
        json.dumps(index, indent=2, sort_keys=True), encoding="utf-8"
    )


def update_index(cache_dir: str | Path, key: str, meta: dict) -> None:
    index = load_index(cache_dir)
    index[key] = meta
    save_index(cache_dir, index)


# --------------------------------------------------------------------------
# Client
# --------------------------------------------------------------------------

class TWClient:
    """Polite, caching Trackwrestling session client."""

    def __init__(
        self,
        season_id: str,
        user_agent: str = DEFAULT_USER_AGENT,
        tw_session_id: str | None = None,
        cache_dir: str | Path = ".twcache",
        delay: float = 1.5,
        jitter: float = 0.7,
        max_requests: int = 300,
        refresh: bool = False,
        timeout: float = 30.0,
        verbose: bool = False,
    ):
        self.season_id = str(season_id)
        # Politeness: never allow a sub-1s floor, regardless of CLI input.
        self.delay = max(1.0, float(delay))
        self.jitter = max(0.0, float(jitter))
        self.max_requests = int(max_requests)
        self.refresh = bool(refresh)
        self.timeout = float(timeout)
        self.verbose = verbose
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        # Manual override: constructor arg wins, then env var.
        self.tw_session_id = tw_session_id or os.environ.get("TW_SESSION_ID") or None

        self.session = requests.Session()
        self.session.headers.update({"User-Agent": user_agent})

        self.request_count = 0
        self._bootstrapped = False

    # -- logging ---------------------------------------------------------
    def _log(self, msg: str) -> None:
        if self.verbose:
            print(f"[twclient] {msg}", flush=True)

    # -- politeness --------------------------------------------------------
    def _sleep_polite(self, seconds: float | None = None) -> None:
        if seconds is None:
            seconds = self.delay + random.uniform(0.0, self.jitter)
        self._log(f"sleeping {seconds:.2f}s")
        time.sleep(seconds)

    def _check_budget(self) -> None:
        if self.request_count >= self.max_requests:
            raise RequestCapExceeded(
                f"request budget exhausted ({self.max_requests}); "
                "raise --max-requests or re-run later (cache is kept)"
            )

    def _get(self, url: str, **kwargs) -> requests.Response:
        """One polite GET: budget check, sleep, request, 429 handling."""
        self._check_budget()
        if self.request_count > 0:
            self._sleep_polite()
        kwargs.setdefault("timeout", self.timeout)
        self._log(f"GET {url} params={kwargs.get('params')}")
        resp = self.session.get(url, **kwargs)
        self.request_count += 1
        if resp.status_code == 429:
            # Honor rate limiting: long backoff, retry exactly once.
            self._log("HTTP 429 — sleeping 30s then retrying once")
            time.sleep(30)
            self._check_budget()
            resp = self.session.get(url, **kwargs)
            self.request_count += 1
        return resp

    # -- bootstrap ---------------------------------------------------------
    def bootstrap(self, entry_url: str | None = None) -> bool:
        """Open a legitimate entry page so USER_SESSIONID is set, then extract
        twSessionId from the returned HTML. Returns True on success."""
        candidates = [
            entry_url,
            f"{BASE_URL}/TWHome.jsp?seasonId={self.season_id}",
            f"{BASE_URL}/Schedule.jsp?seasonId={self.season_id}",
        ]
        for url in [u for u in candidates if u]:
            try:
                resp = self._get(url)
            except requests.RequestException as exc:
                self._log(f"bootstrap GET failed for {url}: {exc}")
                continue
            if resp.status_code >= 400:
                self._log(f"bootstrap entry {url} -> HTTP {resp.status_code}")
                continue
            m = TW_SESSION_RE.search(resp.text)
            if m:
                self.tw_session_id = self.tw_session_id or m.group(1)
                self._log(f"bootstrap OK via {url}; twSessionId acquired")
                self._bootstrapped = True
                return True
            # Page loaded but no token found: cookies are set at least; keep
            # any manually supplied tw_session_id and treat as bootstrapped.
            self._log(f"bootstrap: {url} loaded, no twSessionId in HTML")
            if self.tw_session_id:
                self._bootstrapped = True
                return True
        self._bootstrapped = False
        return False

    # -- EventMatches --------------------------------------------------------
    def _validate_event_matches(self, resp: requests.Response) -> str:
        if resp.status_code != 200:
            raise SessionExpired(
                f"HTTP {resp.status_code} from EventMatches.jsp. {SESSION_GUIDANCE}"
            )
        if "EventMatches.jsp" not in resp.url:
            raise SessionExpired(f"Unexpected redirect to {resp.url}. {SESSION_GUIDANCE}")
        if len(resp.text) < MIN_RESPONSE_BYTES:
            raise SessionExpired(
                f"Response unexpectedly small ({len(resp.text)} bytes). {SESSION_GUIDANCE}"
            )
        return resp.text

    def _request_event_matches(self, event_id: str, team_id: str) -> str:
        params = {
            "TIM": str(int(time.time() * 1000)),
            "twSessionId": self.tw_session_id or "",
            "seasonId": self.season_id,
            "eventId": str(event_id),
            "teamId": str(team_id),
        }
        resp = self._get(EVENT_MATCHES_URL, params=params)
        return self._validate_event_matches(resp)

    def fetch_event_matches(
        self, event_id: str, team_id: str, team_name: str | None = None
    ) -> tuple[str, bool]:
        """Fetch one team's EventMatches page for an event.

        Returns (html, from_cache). Serves from disk cache unless refresh=True.
        On session failure, re-bootstraps and retries exactly once before
        raising SessionExpired.
        """
        key = cache_key(self.season_id, str(event_id), str(team_id))
        path = cache_file(self.cache_dir, key)
        if path.exists() and not self.refresh:
            self._log(f"cache hit event={event_id} team={team_id}")
            return path.read_text(encoding="utf-8"), True

        if not self._bootstrapped and not self.tw_session_id:
            self.bootstrap()

        try:
            html = self._request_event_matches(event_id, team_id)
        except SessionExpired:
            # One retry after a fresh bootstrap, then give up with guidance.
            self._log("session problem; re-bootstrapping and retrying once")
            self._bootstrapped = False
            self.tw_session_id = os.environ.get("TW_SESSION_ID") or None
            if not self.bootstrap() and not self.tw_session_id:
                raise SessionExpired(SESSION_GUIDANCE)
            html = self._request_event_matches(event_id, team_id)

        path.write_text(html, encoding="utf-8")
        update_index(
            self.cache_dir,
            key,
            {
                "season_id": self.season_id,
                "event_id": str(event_id),
                "team_id": str(team_id),
                "team_name": team_name,
                "fetched_at": int(time.time()),
            },
        )
        return html, False

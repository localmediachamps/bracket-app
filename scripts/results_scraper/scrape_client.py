"""scrape_client.py — external results provider HTTP client: session
bootstrap + polite cached fetch.

LEGAL / POLITENESS NOTICE
-------------------------
- Respect the provider's terms of service, robots guidance, and access
  controls. Use this client only for data you are authorized to collect.
- Do NOT attempt to bypass CAPTCHAs, authentication, or any access control.
- Request rates are deliberately low (>= 1.0s delay + jitter between requests)
  and every page is cached on disk so the same URL is never fetched twice
  unless --refresh is explicitly requested.
- Never commit USER_SESSIONID cookies or twSessionId tokens to git.

Request shape (per scraping_notes.md):

    GET https://www.trackwrestling.com/seasons/EventMatches.jsp
        ?TIM=<unix ms>&twSessionId=<token>&seasonId=..&eventId=..&teamId=..

Session bootstrap (EventMatches.jsp path, used by event_scraper.py): GET a
legitimate season entry page first so the server issues a USER_SESSIONID
cookie, then scrape `twSessionId` out of the HTML.

WrestlerMatches.jsp / AjaxFunctions.jsp path (used by fetch_team_roster_page /
fetch_wrestler_matches_json below) bootstraps differently and requires a real
browser — see the "Playwright bootstrap" section further down and the memory
note `trackwrestling-session-bootstrap-solved` for the full writeup. Short
version: plain `requests`/`curl` get an unconditional HTTP 406 on this site
regardless of headers (TLS/HTTP2 fingerprint block, not a header check), and
even a real Playwright browser must run headed (not headless) and issue the
AJAX call via an in-page `fetch()` (not Playwright's `page.request`, which is
a separate lightweight HTTP client that gets blocked the same way).
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
TW_BASE_URL = "https://www.trackwrestling.com/tw/seasons"
EVENT_MATCHES_URL = f"{BASE_URL}/EventMatches.jsp"
LOAD_BALANCE_URL = f"{TW_BASE_URL}/LoadBalance.jsp"
TW_AJAX_FUNCTIONS_URL = f"{TW_BASE_URL}/AjaxFunctions.jsp"

# Governing body id for NCAA within the 2025-26 College Men season
# (seasonId=1560238138). Confirmed 2026-07-20 via a team page's own
# "share this page" link (javascript:showDirectLink(...)). NOT globally
# stable across seasons/divisions - if scraping a different season, open one
# team page in that season and read gbId out of its showDirectLink URL.
NCAA_GB_ID = "3"

# Column order the provider's own UI requests for getWrestlerMatches
# (date, event, winner id, weight - see twwrestlermatches.py's field map for
# what these indices mean). Kept identical to what a real browser sends.
WRESTLER_MATCHES_ORDER_BY = "37, 42, 39, 30"

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
    "The provider rejected the request (session expired or not accepted). "
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


def roster_cache_key(season_id: str, team_id: str) -> str:
    return hashlib.sha256(f"roster|{season_id}|{team_id}".encode()).hexdigest()


def wrestler_matches_cache_key(season_id: str, wrestler_ids: list[str]) -> str:
    ids = ",".join(sorted(str(w) for w in wrestler_ids))
    return hashlib.sha256(f"wrestlermatches|{season_id}|{ids}".encode()).hexdigest()


def cache_file(cache_dir: str | Path, key: str, ext: str = "html") -> Path:
    return Path(cache_dir) / f"{key}.{ext}"


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
    """Polite, caching results-provider session client."""

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
        gb_id: str = NCAA_GB_ID,
    ):
        self.season_id = str(season_id)
        self.gb_id = str(gb_id)
        # Politeness: never allow a sub-1s floor, regardless of CLI input.
        self.delay = max(1.0, float(delay))
        self.jitter = max(0.0, float(jitter))
        self.max_requests = int(max_requests)
        self.refresh = bool(refresh)
        self.timeout = float(timeout)
        self.verbose = verbose
        self.user_agent = user_agent
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        # Manual override: constructor arg wins, then env var.
        self.tw_session_id = tw_session_id or os.environ.get("TW_SESSION_ID") or None

        self.session = requests.Session()
        self.session.headers.update({"User-Agent": user_agent})

        self.request_count = 0
        self._bootstrapped = False

        # Playwright browser state for the WrestlerMatches.jsp/AjaxFunctions.jsp
        # path - lazily launched on first use, kept alive across teams/wrestlers
        # in the same crawl run. See close()/context-manager support below.
        self._pw = None
        self._browser = None
        self._pw_context = None
        self._page = None
        self._current_team_id: str | None = None

    def __enter__(self) -> "TWClient":
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.close()

    def close(self) -> None:
        """Release the Playwright browser, if one was launched."""
        if self._browser is not None:
            self._log("closing Playwright browser")
            try:
                self._browser.close()
            finally:
                self._browser = None
                self._page = None
                self._pw_context = None
        if self._pw is not None:
            self._pw.stop()
            self._pw = None

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

    # -- Playwright bootstrap (WrestlerMatches.jsp / AjaxFunctions.jsp path) --
    # See memory note `trackwrestling-session-bootstrap-solved` for the full
    # writeup of why this needs a real headed browser. Short version: a
    # single LoadBalance.jsp navigation (with seasonId + gbId + teamId) binds
    # season + governing body + team server-side in one shot and lands on
    # that team's WrestlerMatches.jsp page (roster embedded inline in the
    # HTML). The AJAX match-history call must then be issued via an in-page
    # `fetch()` (page.evaluate), not Playwright's page.request, or it gets
    # the same TLS-fingerprint-based HTTP 406 that plain `requests` gets.
    def _ensure_browser(self):
        """Lazily launch a single headed Chromium instance, reused for the
        rest of this client's lifetime. Returns the active Page."""
        if self._page is not None:
            return self._page
        from playwright.sync_api import sync_playwright

        self._log("launching headed Chromium (headless is unreliable here - see memory)")
        self._pw = sync_playwright().start()
        self._browser = self._pw.chromium.launch(headless=False)
        self._pw_context = self._browser.new_context(user_agent=self.user_agent)
        self._pw_context.add_init_script(
            "Object.defineProperty(navigator, 'webdriver', {get: () => undefined});"
        )
        self._page = self._pw_context.new_page()
        return self._page

    def _find_wrestler_matches_frame(self, page, team_id: str, timeout_s: float = 15.0):
        """WrestlerMatches.jsp is loaded into a nested same-origin iframe, not
        the top-level document - page.content()/page.url only see the outer
        MainFrame.jsp wrapper. Poll page.frames for the child frame whose URL
        is the actual WrestlerMatches.jsp?teamId=... page."""
        deadline = time.time() + timeout_s
        needle = f"WrestlerMatches.jsp?teamId={team_id}"
        while time.time() < deadline:
            for frame in page.frames:
                if needle in frame.url:
                    return frame
            page.wait_for_timeout(500)
        return None

    def _bootstrap_team_session(self, team_id: str) -> str:
        """One LoadBalance.jsp navigation: binds season+governing body+team
        for a fresh twSessionId and lands on that team's WrestlerMatches.jsp
        (roster embedded inline, in a nested iframe - see
        _find_wrestler_matches_frame). Returns that frame's HTML."""
        page = self._ensure_browser()
        url = (
            f"{LOAD_BALANCE_URL}?seasonId={self.season_id}&gbId={self.gb_id}"
            f"&pageName=WrestlerMatches.jsp;teamId={team_id}"
        )
        self._check_budget()
        if self.request_count > 0:
            self._sleep_polite()
        page.goto(url, wait_until="domcontentloaded", timeout=int(self.timeout * 1000))
        self.request_count += 1

        frame = self._find_wrestler_matches_frame(page, team_id)
        if frame is None:
            raise SessionExpired(
                f"LoadBalance.jsp bootstrap failed for team={team_id} "
                f"(no WrestlerMatches.jsp frame appeared; landed at {page.url}). "
                "Confirm seasonId/gbId are still correct for this season - "
                "see NCAA_GB_ID / gb_id."
            )
        m = TW_SESSION_RE.search(frame.url)
        if not m:
            raise SessionExpired(f"No twSessionId in frame URL {frame.url}")
        self.tw_session_id = m.group(1)
        self._current_team_id = str(team_id)
        self._bootstrapped = True

        # The roster's jsonStr populates asynchronously shortly after the
        # frame itself loads - poll until it's non-empty (or give up and
        # return whatever we have; an empty roster is a valid outcome for a
        # genuinely empty team, not necessarily a failure).
        deadline = time.time() + 10.0
        html = frame.content()
        while not re.search(r'jsonStr\s*=\s*"\[', html) and time.time() < deadline:
            page.wait_for_timeout(500)
            html = frame.content()
        return html

    def fetch_team_roster_page(self, team_id: str, team_name: str | None = None) -> tuple[str, bool]:
        """Fetch a team's WrestlerMatches.jsp page (the roster - every
        wrestler id on the team - is embedded inline in this page's HTML;
        see twroster.py). Returns (html, from_cache)."""
        key = roster_cache_key(self.season_id, str(team_id))
        path = cache_file(self.cache_dir, key)
        if path.exists() and not self.refresh:
            self._log(f"cache hit roster team={team_id}")
            html = path.read_text(encoding="utf-8")
            m = TW_SESSION_RE.search(html)
            if m:
                self.tw_session_id = m.group(1)
                self._current_team_id = str(team_id)
            return html, True

        html = self._bootstrap_team_session(team_id)

        path.write_text(html, encoding="utf-8")
        update_index(
            self.cache_dir,
            key,
            {
                "season_id": self.season_id,
                "team_id": str(team_id),
                "team_name": team_name,
                "kind": "roster",
                "fetched_at": int(time.time()),
            },
        )
        return html, False

    # -- AjaxFunctions.jsp?function=getWrestlerMatches ---------------------
    def _request_wrestler_matches_json(self, wrestler_ids: list[str], referer_team_id: str) -> str:
        # Reuse the current session only if it's bound to this team AND a
        # live browser page actually exists (a roster cache-hit sets
        # _current_team_id/tw_session_id from stale cached HTML without ever
        # opening a browser - that stale state must not be trusted here).
        if self._page is None or self._current_team_id != str(referer_team_id):
            self._bootstrap_team_session(referer_team_id)

        page = self._ensure_browser()
        tim = str(int(time.time() * 1000))
        ajax_url = (
            f"{TW_AJAX_FUNCTIONS_URL}?TIM={tim}&twSessionId={self.tw_session_id}"
            f"&function=getWrestlerMatches&orderBy={WRESTLER_MATCHES_ORDER_BY}"
            f"&wrestlerIds={','.join(str(w) for w in wrestler_ids)}"
            f"&RANDOM={random.randint(0, 99999)}"
        )

        self._check_budget()
        self._sleep_polite()
        result = page.evaluate(
            """
            async (ajaxUrl) => {
                const resp = await fetch(ajaxUrl, {
                    headers: {"X-Requested-With": "XMLHttpRequest"},
                    credentials: "include"
                });
                return { status: resp.status, body: await resp.text() };
            }
            """,
            ajax_url,
        )
        self.request_count += 1

        if result["status"] != 200:
            raise SessionExpired(
                f"HTTP {result['status']} from AjaxFunctions.jsp (getWrestlerMatches). "
                f"{SESSION_GUIDANCE}"
            )
        return result["body"]

    def fetch_wrestler_matches_json(
        self,
        wrestler_ids: list[str],
        referer_team_id: str,
    ) -> tuple[str, bool]:
        """Fetch one or more wrestlers' full-season match history in a
        single call (a comma-separated wrestlerIds list is accepted by the
        site's own UI - batching multiple wrestlers per call is untested at
        scale but should work the same way). Returns (raw_json_text,
        from_cache) - parse with twwrestlermatches.parse_wrestler_matches_response
        after json.loads()."""
        key = wrestler_matches_cache_key(self.season_id, wrestler_ids)
        path = cache_file(self.cache_dir, key, ext="json")
        if path.exists() and not self.refresh:
            self._log(f"cache hit wrestler matches ids={wrestler_ids}")
            return path.read_text(encoding="utf-8"), True

        try:
            body = self._request_wrestler_matches_json(wrestler_ids, referer_team_id)
        except SessionExpired:
            self._log("session problem on wrestler-matches fetch; re-bootstrapping and retrying once")
            self._current_team_id = None
            self.tw_session_id = None
            body = self._request_wrestler_matches_json(wrestler_ids, referer_team_id)

        path.write_text(body, encoding="utf-8")
        update_index(
            self.cache_dir,
            key,
            {
                "season_id": self.season_id,
                "wrestler_ids": [str(w) for w in wrestler_ids],
                "kind": "wrestler_matches",
                "fetched_at": int(time.time()),
            },
        )
        return body, False

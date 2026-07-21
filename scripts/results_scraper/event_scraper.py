#!/usr/bin/env python3
"""event_scraper.py — legacy per-event results scraper CLI (superseded by
crawl_all_teams.py's team-centric approach; kept for the admin
manual-ingestion workflow's event/parse/push subcommands).

Subcommands:
  teams     regenerate a team-id CSV from a saved team-links HTML page
  fetch     fetch all team EventMatches pages for one event (cached, polite)
  parse     parse cached pages for one event -> platform candidates JSON
  run       fetch -> parse -> normalize -> push to the platform ingestion API
  poll      like run, but repeats every N minutes (live tournaments)
  backfill  iterate a season event index, fetch+parse each event to JSON
            (never pushes — pushing is a separate deliberate `run` step)

Env fallbacks: TW_API_BASE, TW_API_TOKEN, TW_SESSION_ID.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from pathlib import Path
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import scrape_client as twclient
import normalize as twnormalize
import event_match_parser as twparse
import push_results as twpush

EVENT_MATCHES_BASE = "https://www.trackwrestling.com/seasons/EventMatches.jsp"

TEAM_CSV_FIELDS = [
    "team_name", "state", "team_id", "season_id", "event_id",
    "tournament_id", "source_tournament", "event_matches_url_without_session",
]


# --------------------------------------------------------------------------
# Shared helpers (importable for selftest)
# --------------------------------------------------------------------------

def load_teams_csv(path: str) -> list[dict]:
    teams = []
    with open(path, newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            team_id = (row.get("team_id") or "").strip()
            if team_id:
                teams.append(
                    {
                        "team_id": team_id,
                        "team_name": (row.get("team_name") or "").strip() or None,
                    }
                )
    return teams


def make_client(args, season_id: str) -> twclient.TWClient:
    return twclient.TWClient(
        season_id=str(season_id),
        tw_session_id=getattr(args, "tw_session_id", None),
        cache_dir=args.cache_dir,
        delay=args.delay,
        max_requests=args.max_requests,
        refresh=getattr(args, "refresh", False),
        timeout=args.timeout,
        verbose=args.verbose,
    )


def fetch_event_for_teams(client: twclient.TWClient, event_id: str, teams: list[dict]) -> dict:
    counts = {"fetched": 0, "cached": 0, "failed": 0}
    for i, team in enumerate(teams, 1):
        label = f"{team['team_name'] or '?'} ({team['team_id']})"
        try:
            _, from_cache = client.fetch_event_matches(
                event_id, team["team_id"], team_name=team["team_name"]
            )
        except twclient.SessionExpired as exc:
            print(f"ERROR: session problem on team {i}/{len(teams)} {label}:\n  {exc}",
                  file=sys.stderr)
            raise
        except Exception as exc:  # network hiccup on one team: record, continue
            print(f"WARN: fetch failed for {label}: {exc}", file=sys.stderr)
            counts["failed"] += 1
            continue
        counts["cached" if from_cache else "fetched"] += 1
        if client.verbose or not from_cache:
            print(f"  [{i}/{len(teams)}] {'cache' if from_cache else 'fetched'}: {label}",
                  flush=True)
    return counts


def parse_cached_event(
    cache_dir: str,
    event_id: str,
    occurred_at: str | None = None,
    verbose: bool = False,
) -> tuple[list[dict], dict]:
    """Parse every cached page for an event and dedupe into candidates."""
    index = twclient.load_index(cache_dir)
    records = []
    seen_keys = set()
    for key, meta in index.items():
        if str(meta.get("event_id")) != str(event_id):
            continue
        path = twclient.cache_file(cache_dir, key)
        if not path.exists():
            continue
        seen_keys.add(key)
        html = path.read_text(encoding="utf-8")
        records.extend(
            twparse.parse_event_matches(
                html, team_id=meta.get("team_id"), team_name=meta.get("team_name")
            )
        )

    if not seen_keys:
        # Fallback when no index exists: parse every html file without team info.
        for path in sorted(Path(cache_dir).glob("*.html")):
            records.extend(twparse.parse_event_matches(path.read_text(encoding="utf-8")))

    candidates, report = twnormalize.dedupe(records, str(event_id), occurred_at)
    report["pages_parsed"] = len(seen_keys)
    return candidates, report


def print_parse_report(report: dict, event_id: str) -> None:
    print(
        f"event {event_id}: pages={report.get('pages_parsed', 0)} "
        f"rows={report['total_rows']} unique={report['unique_matches']} "
        f"dupes_merged={report['duplicates_merged']} conflicts={len(report['conflicts'])}",
        file=sys.stderr,
    )
    for conflict in report["conflicts"]:
        print(
            f"  CONFLICT {conflict['external_match_key']}: "
            f"winners_seen={conflict['winners_seen']} kept={conflict['kept_winner']}",
            file=sys.stderr,
        )


def extract_team_ids(page_html: str, source_name: str = "") -> list[dict]:
    """Pull team links (EventMatches.jsp?...&teamId=..) out of a saved page."""
    from bs4 import BeautifulSoup

    soup = BeautifulSoup(page_html, "lxml")
    rows: dict[str, dict] = {}
    for anchor in soup.select('a[href*="EventMatches.jsp"]'):
        href = anchor.get("href", "")
        params = parse_qs(urlparse(href).query)
        team_id = params.get("teamId", [None])[0]
        if not team_id:
            continue
        event_id = params.get("eventId", [""])[0]
        season_id = params.get("seasonId", [""])[0]
        tournament_id = params.get("tournamentId", [""])[0]
        label = anchor.get_text(" ", strip=True)
        team_name, sep, state = label.rpartition(", ")
        if not sep:
            team_name, state = label, ""
        rows[team_id] = {
            "team_name": team_name,
            "state": state,
            "team_id": team_id,
            "season_id": season_id,
            "event_id": event_id,
            "tournament_id": tournament_id,
            "source_tournament": source_name,
            "event_matches_url_without_session": (
                f"{EVENT_MATCHES_BASE}?seasonId={season_id}"
                f"&eventId={event_id}&teamId={team_id}"
            ),
        }
    return [rows[k] for k in sorted(rows, key=lambda k: rows[k]["team_name"].casefold())]


# --------------------------------------------------------------------------
# Subcommands
# --------------------------------------------------------------------------

def cmd_teams(args) -> int:
    html = Path(args.html).read_text(encoding="utf-8", errors="replace")
    rows = extract_team_ids(html, source_name=args.name or "")
    if args.out:
        with open(args.out, "w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=TEAM_CSV_FIELDS)
            writer.writeheader()
            writer.writerows(rows)
        print(f"wrote {len(rows)} teams -> {args.out}")
    else:
        writer = csv.DictWriter(sys.stdout, fieldnames=TEAM_CSV_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return 0


def cmd_fetch(args) -> int:
    teams = load_teams_csv(args.teams_csv)
    if not teams:
        print(f"no teams found in {args.teams_csv}", file=sys.stderr)
        return 2
    client = make_client(args, args.season)
    counts = fetch_event_for_teams(client, args.event, teams)
    print(
        f"fetch done: {counts['fetched']} fetched, {counts['cached']} cached, "
        f"{counts['failed']} failed, requests_used={client.request_count}"
    )
    return 0 if counts["failed"] == 0 else 1


def cmd_parse(args) -> int:
    candidates, report = parse_cached_event(
        args.cache_dir, args.event, occurred_at=args.occurred_at, verbose=args.verbose
    )
    Path(args.out).write_text(json.dumps(candidates, indent=2), encoding="utf-8")
    print_parse_report(report, args.event)
    print(f"wrote {len(candidates)} candidates -> {args.out}")
    return 0


def run_cycle(args) -> dict:
    """One full fetch -> parse -> normalize -> push cycle. Returns a summary."""
    summary = {"event": args.event}
    if not args.skip_fetch:
        teams = load_teams_csv(args.teams_csv)
        if not teams:
            raise RuntimeError(f"no teams found in {args.teams_csv}")
        client = make_client(args, args.season)
        summary["fetch"] = fetch_event_for_teams(client, args.event, teams)
    else:
        print("skip-fetch: using cache only")

    candidates, report = parse_cached_event(
        args.cache_dir, args.event, occurred_at=args.occurred_at, verbose=args.verbose
    )
    print_parse_report(report, args.event)
    summary["parse"] = {
        "rows": report["total_rows"],
        "unique": report["unique_matches"],
        "conflicts": len(report["conflicts"]),
    }

    api_base = args.api_base or os.environ.get("TW_API_BASE")
    token = args.token or os.environ.get("TW_API_TOKEN")
    summary["push"] = twpush.push(
        api_base, token, args.source_config, candidates, batch=args.batch
    )
    return summary


def cmd_run(args) -> int:
    run_cycle(args)
    return 0


def cmd_poll(args) -> int:
    interval = max(1.0, args.interval_min) * 60.0
    # Polling implies live results: bypass the cache every cycle.
    args.refresh = True
    cycle = 0
    print(f"polling event {args.event} every {args.interval_min} min (Ctrl+C to stop)")
    try:
        while True:
            cycle += 1
            started = time.strftime("%H:%M:%S")
            try:
                summary = run_cycle(args)
                fetch = summary.get("fetch", {})
                parse = summary.get("parse", {})
                push = summary.get("push", {})
                print(
                    f"cycle {cycle} @ {started}: "
                    f"fetched={fetch.get('fetched', '-')} cached={fetch.get('cached', '-')} "
                    f"rows={parse.get('rows', '-')} unique={parse.get('unique', '-')} "
                    f"created={push.get('created', '-')} duplicates={push.get('duplicates', '-')}",
                    flush=True,
                )
            except twclient.SessionExpired as exc:
                print(f"cycle {cycle}: SESSION EXPIRED — {exc}", file=sys.stderr)
                print("stopping poll; refresh the session and restart", file=sys.stderr)
                return 3
            except Exception as exc:
                print(f"cycle {cycle} failed: {exc}", file=sys.stderr)
            time.sleep(interval)
    except KeyboardInterrupt:
        print(f"\npoll stopped after {cycle} cycle(s)")
        return 0


def cmd_backfill(args) -> int:
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    with open(args.season_index, newline="", encoding="utf-8-sig") as fh:
        rows = [
            r for r in csv.DictReader(fh)
            if (r.get("record_type") or "").strip() == "tournament_event"
        ]
    if args.only_ncaa:
        rows = [r for r in rows if "NCAA Division I" in (r.get("event_name") or "")]
    if args.limit:
        rows = rows[: args.limit]
    if not rows:
        print("no matching tournament_event rows in season index", file=sys.stderr)
        return 2

    teams = load_teams_csv(args.teams_csv)
    clients: dict[str, twclient.TWClient] = {}
    failures = 0

    for i, row in enumerate(rows, 1):
        season_id = (row.get("season_id") or "").strip()
        event_id = (row.get("event_id") or "").strip()
        name = (row.get("event_name") or "").strip()
        occurred_at = (row.get("start_date") or "").strip() or None
        print(f"[{i}/{len(rows)}] {name} (event {event_id})", flush=True)
        try:
            client = clients.get(season_id)
            if client is None:
                client = make_client(args, season_id)
                clients[season_id] = client
            counts = fetch_event_for_teams(client, event_id, teams)
            candidates, report = parse_cached_event(
                args.cache_dir, event_id, occurred_at=occurred_at, verbose=args.verbose
            )
            out_path = out_dir / f"{event_id}.json"
            out_path.write_text(json.dumps(candidates, indent=2), encoding="utf-8")
            print(
                f"  fetched={counts['fetched']} cached={counts['cached']} "
                f"rows={report['total_rows']} unique={report['unique_matches']} "
                f"-> {out_path}",
                flush=True,
            )
        except twclient.SessionExpired as exc:
            print(f"  SESSION EXPIRED on event {event_id}: {exc}", file=sys.stderr)
            print("  stopping backfill — refresh session and re-run (cache is kept)",
                  file=sys.stderr)
            return 3
        except Exception as exc:
            failures += 1
            print(f"  ERROR on event {event_id}: {exc}", file=sys.stderr)

    print(f"backfill done: {len(rows) - failures}/{len(rows)} events written to {out_dir}")
    print("note: backfill never pushes. Push deliberately per event with:")
    print("  python tw.py run --season <s> --event <e> --teams-csv <csv> --skip-fetch \\")
    print("      --source-config <id> --api-base <url> --token <tok>")
    return 0 if failures == 0 else 1


# --------------------------------------------------------------------------
# argparse
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--cache-dir", default=".twcache", help="on-disk page cache dir")
    common.add_argument("--delay", type=float, default=1.5,
                        help="base delay between requests in seconds (floor 1.0)")
    common.add_argument("--max-requests", type=int, default=300,
                        help="per-run HTTP request budget")
    common.add_argument("--timeout", type=float, default=30.0, help="HTTP timeout (s)")
    common.add_argument("--tw-session-id", default=None,
                        help="manual twSessionId override (or env TW_SESSION_ID)")
    common.add_argument("-v", "--verbose", action="store_true")

    parser = argparse.ArgumentParser(prog="tw.py", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("teams", parents=[common],
                       help="regenerate team-id CSV from a saved team-links page")
    p.add_argument("--html", required=True, help="saved HTML page with team links")
    p.add_argument("--out", default=None, help="output CSV path (default: stdout)")
    p.add_argument("--name", default="", help="source tournament name for the CSV")
    p.set_defaults(func=cmd_teams)

    p = sub.add_parser("fetch", parents=[common], help="fetch team pages for an event")
    p.add_argument("--season", required=True)
    p.add_argument("--event", required=True)
    p.add_argument("--teams-csv", required=True)
    p.add_argument("--refresh", action="store_true", help="ignore cache, re-fetch")
    p.set_defaults(func=cmd_fetch)

    p = sub.add_parser("parse", parents=[common], help="parse cached pages -> candidates JSON")
    p.add_argument("--event", required=True)
    p.add_argument("--out", required=True, help="output JSON path")
    p.add_argument("--occurred-at", default=None, help="event date YYYY-MM-DD")
    p.set_defaults(func=cmd_parse)

    p = sub.add_parser("run", parents=[common],
                       help="fetch -> parse -> normalize -> push (one shot)")
    p.add_argument("--season", required=True)
    p.add_argument("--event", required=True)
    p.add_argument("--teams-csv", required=True)
    p.add_argument("--source-config", required=True, help="results_source_config id")
    p.add_argument("--api-base", default=None, help="or env TW_API_BASE")
    p.add_argument("--token", default=None, help="or env TW_API_TOKEN")
    p.add_argument("--batch", type=int, default=100)
    p.add_argument("--occurred-at", default=None, help="event date YYYY-MM-DD")
    p.add_argument("--skip-fetch", action="store_true", help="use cache only")
    p.add_argument("--refresh", action="store_true", help="ignore cache, re-fetch")
    p.add_argument("--once", action="store_true",
                   help="accepted for clarity; run is always a single cycle")
    p.set_defaults(func=cmd_run)

    p = sub.add_parser("poll", parents=[common], help="run every N minutes (live)")
    p.add_argument("--season", required=True)
    p.add_argument("--event", required=True)
    p.add_argument("--teams-csv", required=True)
    p.add_argument("--source-config", required=True)
    p.add_argument("--api-base", default=None)
    p.add_argument("--token", default=None)
    p.add_argument("--batch", type=int, default=100)
    p.add_argument("--occurred-at", default=None)
    p.add_argument("--skip-fetch", action="store_true")
    p.add_argument("--interval-min", type=float, default=15.0)
    p.set_defaults(func=cmd_poll)

    p = sub.add_parser("backfill", parents=[common],
                       help="fetch+parse every event in a season index (never pushes)")
    p.add_argument("--season-index", required=True, help="event index CSV")
    p.add_argument("--teams-csv", required=True)
    p.add_argument("--out-dir", required=True)
    p.add_argument("--limit", type=int, default=None)
    p.add_argument("--only-ncaa", action="store_true",
                   help='only events whose name contains "NCAA Division I"')
    p.add_argument("--refresh", action="store_true")
    p.set_defaults(func=cmd_backfill)

    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except twclient.RequestCapExceeded as exc:
        print(f"request budget exhausted: {exc}", file=sys.stderr)
        return 4
    except twclient.SessionExpired as exc:
        print(f"session expired: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())

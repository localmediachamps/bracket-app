"""crawl_all_teams.py — full NCAA D1 crawl: every team in
results_scraper_bundle/ncaa_d1_team_ids_2025_26.csv gets its roster fetched,
then one batched getWrestlerMatches call for its whole roster. Output is a
single combined CSV shaped for wrestler_match_history (same columns as the
Air Force test batch), deduped by source_match_id across the whole run - a
match between two scraped teams would otherwise appear twice (once per
team's batch).

Run:  python scripts/results_scraper/crawl_all_teams.py [--out FILE] [--limit N]

Uses the season/gbId already confirmed for 2025-26 College Men NCAA
(see NCAA_GB_ID in scrape_client.py). Respects TWClient's politeness delay
between requests; expect roughly 74 teams * ~10-15s each (page navigation +
frame settle + AJAX call) - a full run takes several minutes with a real,
visible Chromium window (see trackwrestling-session-bootstrap-solved memory
note for why headless doesn't work here).
"""

from __future__ import annotations

import argparse
import csv
import datetime
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from scrape_client import TWClient, SessionExpired
from roster_parser import parse_roster_page
from match_parser import parse_wrestler_matches_response, to_candidate

DEFAULT_SEASON_ID = "1560238138"  # 2025-26 College Men
DEFAULT_TEAM_CSV = Path(__file__).parent.parent.parent / "results_scraper_bundle" / "ncaa_d1_team_ids_2025_26.csv"

# raw_row is intentionally excluded from the CSV: Xano's dashboard CSV
# importer chokes on a JSON-array-as-quoted-CSV-cell (nested quotes/commas).
# It stays in the table schema as optional - can be backfilled later from a
# re-scrape (idempotent) if ever needed, rather than fighting CSV escaping.
FIELDS = [
    "winner_name_raw", "loser_name_raw", "winner_school_raw", "loser_school_raw",
    "winner_class_year_raw", "loser_class_year_raw", "weight_class", "victory_type",
    "round_label", "round_sort_key", "level", "event_name", "event_series_name",
    "event_type", "event_id_external", "date_start_raw", "date_end_raw", "occurred_at",
    "source_match_id", "extraction_confidence", "score", "time_seconds",
]


def parse_occurred_at(date_start):
    """Returns epoch milliseconds (matching Xano's own timestamp
    representation) or None - not an ISO string, which Xano's CSV importer
    doesn't reliably parse for timestamp columns."""
    if not date_start:
        return None
    s = str(date_start)
    try:
        if len(s) == 8:
            dt = datetime.datetime.strptime(s, "%Y%m%d").replace(tzinfo=datetime.timezone.utc)
        elif len(s) == 12:
            dt = datetime.datetime.strptime(s, "%Y%m%d%H%M").replace(tzinfo=datetime.timezone.utc)
        else:
            return None
    except ValueError:
        return None
    return int(dt.timestamp() * 1000)


def load_teams(team_csv: Path, limit: int | None = None) -> list[dict]:
    with open(team_csv, encoding="utf-8") as f:
        teams = list(csv.DictReader(f))
    return teams[:limit] if limit else teams


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="ncaa_d1_matches.csv")
    ap.add_argument("--limit", type=int, default=None, help="only crawl the first N teams (testing)")
    ap.add_argument("--cache-dir", default=".scrape_cache")
    ap.add_argument("--season-id", default=DEFAULT_SEASON_ID)
    ap.add_argument("--gb-id", default="3")
    ap.add_argument("--team-csv", default=str(DEFAULT_TEAM_CSV))
    args = ap.parse_args()

    teams = load_teams(Path(args.team_csv), args.limit)
    print(f"crawling {len(teams)} teams (season_id={args.season_id}, gb_id={args.gb_id})...")

    seen_match_ids: set[str] = set()
    all_records: list[dict] = []
    failures: list[tuple[str, str]] = []

    with TWClient(
        season_id=args.season_id,
        gb_id=args.gb_id,
        cache_dir=args.cache_dir,
        verbose=True,
        max_requests=len(teams) * 3 + 20,
    ) as client:
        for i, team in enumerate(teams, 1):
            team_name = team["team_name"]
            team_id = team["team_id"]
            print(f"\n[{i}/{len(teams)}] {team_name} (team_id={team_id})")
            try:
                html, from_cache = client.fetch_team_roster_page(team_id, team_name=team_name)
                roster = parse_roster_page(html)
                if not roster:
                    print(f"  WARNING: empty roster for {team_name}, skipping")
                    failures.append((team_name, "empty roster"))
                    continue
                ids = [w.wrestler_id for w in roster]
                print(f"  roster: {len(roster)} wrestlers (from_cache={from_cache})")

                body, from_cache2 = client.fetch_wrestler_matches_json(ids, referer_team_id=team_id)
                rows = json.loads(body)
                matches = parse_wrestler_matches_response(rows)
                print(f"  matches: {len(matches)} raw rows (from_cache={from_cache2})")

                new_count = 0
                for m in matches:
                    c = to_candidate(m)
                    if c is None or m.match_id in seen_match_ids:
                        continue
                    seen_match_ids.add(m.match_id)
                    new_count += 1
                    all_records.append({
                        "winner_name_raw": m.winner_name, "loser_name_raw": m.loser_name,
                        "winner_school_raw": m.winner_school, "loser_school_raw": m.loser_school,
                        "winner_class_year_raw": m.winner_class_year, "loser_class_year_raw": m.loser_class_year,
                        "weight_class": m.weight, "victory_type": m.victory_type,
                        "round_label": m.round_label, "round_sort_key": m.round_sort_key, "level": m.level,
                        "event_name": m.event_name, "event_series_name": m.event_series_name,
                        "event_type": m.event_type, "event_id_external": m.event_id,
                        "date_start_raw": m.date_start, "date_end_raw": m.date_end,
                        "occurred_at": parse_occurred_at(m.date_start),
                        "source_match_id": m.match_id,
                        "extraction_confidence": c["extraction_confidence"],
                        "score": m.score,
                        "time_seconds": m.time_seconds,
                    })
                print(f"  added {new_count} new unique matches (running total: {len(all_records)})")
            except SessionExpired as exc:
                print(f"  FAILED: {exc}")
                failures.append((team_name, str(exc)))
                continue

    out_path = Path(args.out)
    with open(out_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(all_records)

    print(f"\n{'='*60}")
    print(f"wrote {len(all_records)} unique match records to {out_path}")
    if failures:
        print(f"{len(failures)} team(s) failed:")
        for name, reason in failures:
            print(f"  - {name}: {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

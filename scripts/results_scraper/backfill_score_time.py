"""backfill_score_time.py — re-derive `score`/`time_seconds` for matches
already imported into wrestler_match_history, by re-parsing the raw
getWrestlerMatches JSON already sitting in a local scrape cache directory
(NO live re-scraping - see match_parser.py's score/time decode logic added
2026-07-21).

Re-sends every field for each match (not just score/time_seconds), since
admin_wrestler_match_history_upsert_POST.xs's db.add_or_edit sets every key
in its data map explicitly - a partial payload with only source_match_id +
score would null out every other column on the existing row. Re-parsing from
the same cache the original import used means every other field's value is
identical to what's already stored, so this is safe.

Only covers cache directories that actually exist on disk locally - a season
whose cache was never fetched (or was cleaned up) can't be backfilled this
way and needs a fresh (re-)scrape via crawl_all_teams.py instead.

Usage:
  python backfill_score_time.py --cache-dir .scrape_cache_2024_25 \
      --api-base https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y \
      --token <admin-token> [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from match_parser import parse_wrestler_matches_response, to_candidate

import requests

BATCH_SIZE = 500


def parse_occurred_at(date_start):
    import datetime

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


def build_records(cache_dir: Path) -> list[dict]:
    seen_match_ids: set[str] = set()
    records: list[dict] = []
    json_files = sorted(cache_dir.glob("*.json"))
    print(f"found {len(json_files)} cached JSON responses in {cache_dir}")

    for path in json_files:
        try:
            rows = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            print(f"  WARNING: could not read {path.name}: {exc}")
            continue
        if not isinstance(rows, list):
            continue

        matches = parse_wrestler_matches_response(rows)
        for m in matches:
            c = to_candidate(m)
            if c is None or m.match_id in seen_match_ids:
                continue
            seen_match_ids.add(m.match_id)
            records.append({
                "source_match_id": m.match_id,
                "winner_name_raw": m.winner_name,
                "loser_name_raw": m.loser_name,
                "winner_school_raw": m.winner_school,
                "loser_school_raw": m.loser_school,
                "winner_class_year_raw": m.winner_class_year,
                "loser_class_year_raw": m.loser_class_year,
                "weight_class": m.weight,
                "victory_type": m.victory_type,
                "round_label": m.round_label,
                "round_sort_key": m.round_sort_key,
                "level": m.level,
                "event_name": m.event_name,
                "event_series_name": m.event_series_name,
                "event_type": m.event_type,
                "event_id_external": m.event_id,
                "date_start_raw": m.date_start,
                "date_end_raw": m.date_end,
                "occurred_at": parse_occurred_at(m.date_start),
                "extraction_confidence": c["extraction_confidence"],
                "score": m.score,
                "time_seconds": m.time_seconds,
            })

    print(f"built {len(records)} unique match records")
    return records


def push(records: list[dict], api_base: str, token: str, dry_run: bool) -> None:
    total_processed = 0
    total_errors = 0
    url = f"{api_base.rstrip('/')}/admin/wrestler-match-history/upsert"

    for i in range(0, len(records), BATCH_SIZE):
        batch = records[i:i + BATCH_SIZE]
        if dry_run:
            print(f"[dry-run] batch {i // BATCH_SIZE + 1}: {len(batch)} records (not sent)")
            continue

        resp = requests.post(
            url,
            json={"matches": batch},
            headers={"Authorization": f"Bearer {token}"},
            timeout=120,
        )
        if resp.status_code >= 400:
            print(f"batch {i // BATCH_SIZE + 1} FAILED: HTTP {resp.status_code} — {resp.text[:300]}")
            continue

        data = resp.json()
        total_processed += data.get("processed", 0)
        total_errors += data.get("error_count", 0)
        print(f"batch {i // BATCH_SIZE + 1}: processed={data.get('processed')} errors={data.get('error_count')}")
        if data.get("errors"):
            for err in data["errors"][:5]:
                print(f"    error: {err}")
        time.sleep(0.3)

    if not dry_run:
        print(f"\nTOTAL: processed={total_processed} errors={total_errors} of {len(records)} records")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache-dir", required=True, help="local scrape cache dir, e.g. .scrape_cache_2024_25")
    ap.add_argument("--api-base", default=None, help="Xano admin API base, e.g. https://.../api:PBpa1T2y")
    ap.add_argument("--token", default=None, help="admin bearer token")
    ap.add_argument("--dry-run", action="store_true", help="build records and print counts, don't push")
    args = ap.parse_args()

    cache_dir = Path(args.cache_dir)
    if not cache_dir.is_dir():
        print(f"cache dir not found: {cache_dir}")
        return 1

    records = build_records(cache_dir)
    if not records:
        print("nothing to push")
        return 0

    if not args.dry_run and not (args.api_base and args.token):
        print("--api-base and --token are required unless --dry-run is set")
        return 1

    push(records, args.api_base or "", args.token or "", args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

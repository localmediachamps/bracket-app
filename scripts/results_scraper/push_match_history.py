"""push_match_history.py — bulk-pushes match-history CSV rows (the
crawl_all_teams.py / resolve_team_ids.py output shape) into
wrestler_match_history via admin/wrestler-match-history/upsert, in batches.
Idempotent on source_match_id (db.add_or_edit server-side) - safe to re-run
or to push overlapping data (e.g. two different teams' crawls that share a
match) without creating duplicates.

Usage:
  python push_match_history.py --api-base https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y \
      --in results_scraper_bundle/missing5_matches_2025_26.csv
"""

from __future__ import annotations

import argparse
import csv
import time

import requests

BATCH_SIZE = 500

FIELDS = [
    "source_match_id", "winner_name_raw", "loser_name_raw",
    "winner_school_raw", "loser_school_raw",
    "winner_class_year_raw", "loser_class_year_raw",
    "weight_class", "victory_type", "score", "time_seconds",
    "round_label", "round_sort_key", "level",
    "event_name", "event_series_name", "event_type", "event_id_external",
    "date_start_raw", "date_end_raw", "occurred_at", "extraction_confidence",
]


def row_to_payload(row: dict) -> dict:
    out = {}
    for f in FIELDS:
        v = row.get(f)
        if v == "" or v is None:
            continue
        if f in ("time_seconds", "occurred_at"):
            try:
                v = int(float(v))
            except ValueError:
                continue
        elif f == "extraction_confidence":
            try:
                v = float(v)
            except ValueError:
                continue
        out[f] = v
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--api-base", required=True)
    ap.add_argument("--in", dest="in_path", required=True)
    args = ap.parse_args()

    with open(args.in_path, encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    payloads = [row_to_payload(r) for r in rows if r.get("source_match_id")]
    print(f"pushing {len(payloads)} match rows from {args.in_path}...")

    url = f"{args.api_base}/admin/wrestler-match-history/upsert"
    total_processed = 0
    total_errors = 0
    for i in range(0, len(payloads), BATCH_SIZE):
        batch = payloads[i:i + BATCH_SIZE]
        resp = requests.post(url, json={"matches": batch}, timeout=180)
        if resp.status_code >= 400:
            print(f"  batch {i // BATCH_SIZE + 1} FAILED: HTTP {resp.status_code} - {resp.text[:300]}")
            continue
        data = resp.json()
        total_processed += data.get("processed", 0)
        total_errors += data.get("error_count", 0)
        print(f"  batch {i // BATCH_SIZE + 1}: received={data.get('received')} processed={data.get('processed')} errors={data.get('error_count')}")
        if data.get("errors"):
            for err in data["errors"][:5]:
                print(f"      error: {err}")
        time.sleep(0.2)

    print(f"\nTOTAL: processed={total_processed} errors={total_errors} of {len(payloads)} rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

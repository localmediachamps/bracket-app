"""build_score_time_paste_csv.py — produce one CSV covering every row
currently in wrestler_match_history (id, source_match_id, score,
time_seconds), for Garrett's own update function to consume. No admin login
needed - reads via the public /results/matches search endpoint to learn
every row's internal id + source_match_id, then joins in score/time
re-derived locally from cached scrape JSON where we have it
(backfill_score_time.py / match_parser.py).

Covers ALL seasons currently in the table, not just the ones we have local
cache for - rows from a season we can't backfill yet (2023-24, as of
2026-07-21) are still included, just with score/time left blank, so this is
one complete list rather than a partial one.

Usage:
  python build_score_time_paste_csv.py --out score_time_paste.csv
"""

from __future__ import annotations

import argparse
import csv
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from backfill_score_time import build_records

import requests

API_BASE = "https://xhuf-7flt-jytp.n7d.xano.io/api:17Ryya5W"
PER_PAGE = 100


def fetch_id_mapping() -> dict[str, int]:
    """source_match_id -> internal id, for every row in the table (all
    seasons) - covers rows we don't have local score/time for too, so the
    output CSV has one row per DB record, not just the ones we can fill in."""
    mapping: dict[str, int] = {}
    page = 1
    session = requests.Session()
    while True:
        resp = session.get(
            f"{API_BASE}/results/matches",
            params={"page": page, "per": PER_PAGE},
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
        items = data.get("items", [])
        if not items:
            break
        for row in items:
            smid = row.get("source_match_id")
            if smid:
                mapping[smid] = row["id"]
        total = data.get("total")
        print(f"  page {page}: +{len(items)} rows (mapping size {len(mapping)}{f'/{total}' if total else ''})")
        if len(items) < PER_PAGE:
            break
        page += 1
        time.sleep(0.05)
    return mapping


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="score_time_paste.csv")
    ap.add_argument(
        "--cache-dirs", nargs="+", default=[".scrape_cache", ".scrape_cache_2024_25"],
        help="local cache dirs to rebuild score/time from",
    )
    args = ap.parse_args()

    print("re-deriving score/time from local cache...")
    local_records: dict[str, dict] = {}
    for cd in args.cache_dirs:
        for r in build_records(Path(cd)):
            local_records[r["source_match_id"]] = r

    print(f"\ntotal locally-derived records: {len(local_records)}")

    print("\nfetching id mapping from the public /results/matches endpoint...")
    id_mapping = fetch_id_mapping()
    print(f"total id mapping size: {len(id_mapping)}")

    # One row per DB record - every id_mapping entry, whether or not we have
    # local score/time for it (rows from a season we haven't re-scraped yet
    # just get blank score/time, same shape, still present in the file).
    rows = []
    filled = 0
    for smid, row_id in id_mapping.items():
        rec = local_records.get(smid)
        if rec is not None:
            filled += 1
        rows.append({
            "id": row_id,
            "score": (rec["score"] or "") if rec else "",
            "time_seconds": (rec["time_seconds"] if rec["time_seconds"] is not None else "") if rec else "",
        })

    rows.sort(key=lambda r: r["id"])

    out_path = Path(args.out)
    with open(out_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["id", "score", "time_seconds"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nwrote {len(rows)} rows to {out_path} ({filled} with score/time filled in, {len(rows) - filled} blank)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

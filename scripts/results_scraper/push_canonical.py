"""push_canonical.py — pushes canonical_teams_pending.json and
canonical_wrestlers_pending.json (built by build_canonical_wrestlers.py) into
Xano, then backfills wrestler_match_history.winner/loser_canonical_wrestler_id
across all 4 season CSVs using the resulting (name, school) -> id mapping.

Three phases, run in order (each is idempotent-safe to resume if it dies
partway - re-run and it picks up from where the *_pushed.json files show
progress, though phase 2 (wrestlers) is a plain create so don't re-run it
after a partial success without checking canonical_wrestlers_pushed.json
first):
  1. Push teams -> canonical_teams_pushed.json ({name: id})
  2. Push wrestlers (using team ids from step 1) -> canonical_wrestlers_pushed.json ({"name|||school": id})
  3. Backfill wrestler_match_history via admin/wrestler-match-history/canonical-backfill

Usage:
  python push_canonical.py --api-base https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y --token none --phase teams
  python push_canonical.py --api-base ... --token none --phase wrestlers
  python push_canonical.py --api-base ... --token none --phase backfill
"""

from __future__ import annotations

import argparse
import csv
import json
import time
from pathlib import Path

import requests

HERE = Path(__file__).parent
BATCH_SIZE = 500

CSVS = [
    HERE / "ncaa_d1_matches.csv",
    HERE / "ncaa_d1_matches_2024_25.csv",
    HERE / "ncaa_d1_matches_2023_24_rescrape.csv",
    HERE / "ncaa_d1_matches_2022_23.csv",
]


def norm(s: str | None) -> str:
    return " ".join((s or "").split()).strip()


def post_batches(url: str, token: str, key: str, items: list[dict], label: str) -> list[dict]:
    all_results = []
    for i in range(0, len(items), BATCH_SIZE):
        batch = items[i:i + BATCH_SIZE]
        resp = requests.post(
            url,
            json={key: batch},
            headers={"Authorization": f"Bearer {token}"},
            timeout=120,
        )
        if resp.status_code >= 400:
            print(f"  batch {i // BATCH_SIZE + 1} FAILED: HTTP {resp.status_code} - {resp.text[:300]}")
            continue
        data = resp.json()
        results = data.get("results", [])
        all_results.extend(results)
        print(f"  {label} batch {i // BATCH_SIZE + 1}: {len(results)} ok, {data.get('error_count', 0)} errors")
        if data.get("errors"):
            for err in data["errors"][:5]:
                print(f"      error: {err}")
        time.sleep(0.2)
    return all_results


def phase_teams(api_base: str, token: str) -> None:
    teams = json.loads((HERE / "canonical_teams_pending.json").read_text(encoding="utf-8"))
    print(f"pushing {len(teams)} teams...")
    results = post_batches(
        f"{api_base}/admin/canonical/teams/bulk-add", token, "teams",
        [{"name": t["name"]} for t in teams], "teams",
    )
    mapping = {r["name"]: r["id"] for r in results}
    (HERE / "canonical_teams_pushed.json").write_text(json.dumps(mapping), encoding="utf-8")
    print(f"wrote canonical_teams_pushed.json ({len(mapping)} teams mapped)")


def phase_wrestlers(api_base: str, token: str) -> None:
    wrestlers = json.loads((HERE / "canonical_wrestlers_pending.json").read_text(encoding="utf-8"))
    team_map = json.loads((HERE / "canonical_teams_pushed.json").read_text(encoding="utf-8"))
    team_id_to_name = {v: k for k, v in team_map.items()}
    print(f"pushing {len(wrestlers)} wrestlers...")

    payload = []
    skipped = 0
    for w in wrestlers:
        team_id = team_map.get(w["team_name"])
        if team_id is None:
            skipped += 1
            continue
        payload.append({"display_name": w["display_name"], "current_team_id": team_id})
    if skipped:
        print(f"  WARNING: {skipped} wrestlers skipped (no matching team id)")

    # Build the mapping from the RESPONSE's own echoed display_name/
    # current_team_id (not by zipping request/response by position) - a
    # dropped/failed row would silently misalign a positional zip.
    results = post_batches(
        f"{api_base}/admin/canonical/wrestlers/bulk-add", token, "wrestlers", payload, "wrestlers",
    )
    mapping = {}
    for r in results:
        school = team_id_to_name.get(r.get("current_team_id"))
        if school is None:
            continue
        mapping[f"{r['display_name']}|||{school}"] = r["id"]
    (HERE / "canonical_wrestlers_pushed.json").write_text(json.dumps(mapping), encoding="utf-8")
    print(f"wrote canonical_wrestlers_pushed.json ({len(mapping)} wrestlers mapped)")


def phase_backfill(api_base: str, token: str) -> None:
    wrestler_map = json.loads((HERE / "canonical_wrestlers_pushed.json").read_text(encoding="utf-8"))
    print(f"loaded {len(wrestler_map)} canonical wrestler mappings")

    seen_match_ids: set[str] = set()
    rows_out = []
    for csv_path in CSVS:
        if not csv_path.exists():
            continue
        with open(csv_path, encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        for r in rows:
            smid = r.get("source_match_id")
            if not smid or smid in seen_match_ids:
                continue
            seen_match_ids.add(smid)
            wname = norm(r.get("winner_name_raw"))
            wschool = norm(r.get("winner_school_raw"))
            lname = norm(r.get("loser_name_raw"))
            lschool = norm(r.get("loser_school_raw"))
            winner_id = wrestler_map.get(f"{wname}|||{wschool}")
            loser_id = wrestler_map.get(f"{lname}|||{lschool}")
            if winner_id is None and loser_id is None:
                continue
            rows_out.append({
                "source_match_id": smid,
                "winner_canonical_wrestler_id": winner_id,
                "loser_canonical_wrestler_id": loser_id,
            })

    print(f"built {len(rows_out)} backfill rows (of {len(seen_match_ids)} unique matches)")

    total_processed = 0
    total_errors = 0
    for i in range(0, len(rows_out), BATCH_SIZE):
        batch = rows_out[i:i + BATCH_SIZE]
        resp = requests.post(
            f"{api_base}/admin/wrestler-match-history/canonical-backfill",
            json={"rows": batch},
            headers={"Authorization": f"Bearer {token}"},
            timeout=180,
        )
        if resp.status_code >= 400:
            print(f"  batch {i // BATCH_SIZE + 1} FAILED: HTTP {resp.status_code} - {resp.text[:300]}")
            continue
        data = resp.json()
        total_processed += data.get("processed", 0)
        total_errors += data.get("error_count", 0)
        print(f"  backfill batch {i // BATCH_SIZE + 1}: processed={data.get('processed')} errors={data.get('error_count')}")
        time.sleep(0.2)

    print(f"\nTOTAL backfill: processed={total_processed} errors={total_errors} of {len(rows_out)} rows")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--api-base", required=True)
    ap.add_argument("--token", required=True)
    ap.add_argument("--phase", required=True, choices=["teams", "wrestlers", "backfill"])
    args = ap.parse_args()

    if args.phase == "teams":
        phase_teams(args.api_base, args.token)
    elif args.phase == "wrestlers":
        phase_wrestlers(args.api_base, args.token)
    elif args.phase == "backfill":
        phase_backfill(args.api_base, args.token)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

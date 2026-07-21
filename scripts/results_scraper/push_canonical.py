"""push_canonical.py — pushes canonical_teams_pending.json,
canonical_wrestlers_pending.json, and the wrestler<->team links (built by
build_canonical_wrestlers.py, 2026-07-22 many-to-many version) into Xano,
then backfills wrestler_match_history.winner/loser_canonical_wrestler_id
using identity_backfill_map.json.

Four phases, run in order:
  1. teams        -> canonical_teams_pushed.json ({name: id})
  2. wrestlers     -> canonical_wrestlers_pushed.json ({pending-list-index: id})
                      Positional correlation between request and response is
                      safe here specifically because admin/canonical/
                      wrestlers/bulk-add has no try_catch around its db.add -
                      a batch either fully succeeds (N results, same order as
                      the input) or fully fails (no partial/reordered result),
                      so index-in-batch always lines up.
  3. wrestler-teams -> pushes canonical_wrestler_team join rows (needs
                      canonical_wrestlers_pushed.json + canonical_teams_pushed.json)
  4. backfill      -> wrestler_match_history via
                      admin/wrestler-match-history/canonical-backfill

Usage:
  python push_canonical.py --api-base https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y --token none --phase teams
  python push_canonical.py --api-base ... --token none --phase wrestlers
  python push_canonical.py --api-base ... --token none --phase wrestler-teams
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
BUNDLE = HERE.parent.parent / "results_scraper_bundle"
BATCH_SIZE = 500

SEASON_CSVS = [
    (HERE / "ncaa_d1_matches.csv", "2025-26"),
    (HERE / "ncaa_d1_matches_2024_25.csv", "2024-25"),
    (HERE / "ncaa_d1_matches_2023_24_rescrape.csv", "2023-24"),
    (HERE / "ncaa_d1_matches_2022_23.csv", "2022-23"),
    (BUNDLE / "missing5_matches_2025_26.csv", "2025-26"),
    (BUNDLE / "missing5_matches_2024_25.csv", "2024-25"),
    (BUNDLE / "missing5_matches_2023_24.csv", "2023-24"),
    (BUNDLE / "missing5_matches_2022_23.csv", "2022-23"),
]

SCHOOL_ALIASES = {
    "Presbyterian College": "Presbyterian",
    "sacred heart": "Sacred Heart",
}


def norm(s: str | None) -> str:
    return " ".join((s or "").split()).strip()


def post_batches(url: str, token: str, key: str, items: list[dict], label: str) -> list[dict | None]:
    """Returns one entry per input item (None for items in a failed batch),
    same length/order as `items` - callers rely on this for positional
    correlation back to the pending list."""
    all_results: list[dict | None] = []
    for i in range(0, len(items), BATCH_SIZE):
        batch = items[i:i + BATCH_SIZE]
        resp = requests.post(
            url,
            json={key: batch},
            headers={"Authorization": f"Bearer {token}"},
            timeout=180,
        )
        if resp.status_code >= 400:
            print(f"  batch {i // BATCH_SIZE + 1} FAILED: HTTP {resp.status_code} - {resp.text[:300]}")
            all_results.extend([None] * len(batch))
            continue
        data = resp.json()
        results = data.get("results", [])
        if len(results) != len(batch):
            print(f"  batch {i // BATCH_SIZE + 1}: WARNING result count {len(results)} != batch size {len(batch)}, padding with None")
            results = results + [None] * (len(batch) - len(results))
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
    mapping = {r["name"]: r["id"] for r in results if r}
    (HERE / "canonical_teams_pushed.json").write_text(json.dumps(mapping), encoding="utf-8")
    print(f"wrote canonical_teams_pushed.json ({len(mapping)} teams mapped)")


def phase_wrestlers(api_base: str, token: str) -> None:
    wrestlers = json.loads((HERE / "canonical_wrestlers_pending.json").read_text(encoding="utf-8"))
    team_map = json.loads((HERE / "canonical_teams_pushed.json").read_text(encoding="utf-8"))
    print(f"pushing {len(wrestlers)} wrestlers...")

    payload = []
    for w in wrestlers:
        payload.append({
            "display_name": w["display_name"],
            "current_team_id": team_map.get(w["current_team_name"]),
            "legal_first_name": w.get("legal_first_name") or None,
            "legal_last_name": w.get("legal_last_name") or None,
        })

    results = post_batches(
        f"{api_base}/admin/canonical/wrestlers/bulk-add", token, "wrestlers", payload, "wrestlers",
    )
    # index (position in canonical_wrestlers_pending.json) -> real id
    mapping = {str(i): r["id"] for i, r in enumerate(results) if r}
    (HERE / "canonical_wrestlers_pushed.json").write_text(json.dumps(mapping), encoding="utf-8")
    ok = len(mapping)
    print(f"wrote canonical_wrestlers_pushed.json ({ok}/{len(wrestlers)} wrestlers mapped)")


def phase_wrestler_teams(api_base: str, token: str) -> None:
    wrestlers = json.loads((HERE / "canonical_wrestlers_pending.json").read_text(encoding="utf-8"))
    wrestler_map = json.loads((HERE / "canonical_wrestlers_pushed.json").read_text(encoding="utf-8"))
    team_map = json.loads((HERE / "canonical_teams_pushed.json").read_text(encoding="utf-8"))

    payload = []
    skipped = 0
    for i, w in enumerate(wrestlers):
        wrestler_id = wrestler_map.get(str(i))
        if wrestler_id is None:
            skipped += 1
            continue
        for link in w["team_links"]:
            team_id = team_map.get(link["team_name"])
            if team_id is None:
                skipped += 1
                continue
            payload.append({
                "canonical_wrestler_id": wrestler_id,
                "canonical_team_id": team_id,
                "season_label": link["season_label"],
                "match_count": link.get("match_count"),
            })
    if skipped:
        print(f"  WARNING: {skipped} links skipped (missing wrestler/team id)")

    print(f"pushing {len(payload)} wrestler-team links...")
    post_batches(
        f"{api_base}/admin/canonical/wrestler-teams/bulk-add", token, "links", payload, "wrestler-teams",
    )


def phase_backfill(api_base: str, token: str) -> None:
    identity_map = json.loads((HERE / "identity_backfill_map.json").read_text(encoding="utf-8"))
    wrestler_map = json.loads((HERE / "canonical_wrestlers_pushed.json").read_text(encoding="utf-8"))
    print(f"loaded {len(identity_map)} identity keys, {len(wrestler_map)} pushed wrestler ids")

    def resolve(name: str, season: str, school_raw: str) -> int | None:
        school = SCHOOL_ALIASES.get(school_raw, school_raw)
        idx = identity_map.get(f"{name}|||{season}|||{school}")
        if idx is None:
            return None
        return wrestler_map.get(str(idx))

    seen_match_ids: set[str] = set()
    rows_out = []
    for csv_path, season in SEASON_CSVS:
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
            winner_id = resolve(wname, season, wschool) if wname and wschool else None
            loser_id = resolve(lname, season, lschool) if lname and lschool else None
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
    ap.add_argument("--phase", required=True, choices=["teams", "wrestlers", "wrestler-teams", "backfill"])
    args = ap.parse_args()

    if args.phase == "teams":
        phase_teams(args.api_base, args.token)
    elif args.phase == "wrestlers":
        phase_wrestlers(args.api_base, args.token)
    elif args.phase == "wrestler-teams":
        phase_wrestler_teams(args.api_base, args.token)
    elif args.phase == "backfill":
        phase_backfill(args.api_base, args.token)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

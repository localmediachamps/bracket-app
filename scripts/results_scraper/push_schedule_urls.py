"""push_schedule_urls.py - pushes schedule_url_payload.json (team name ->
official schedule page URL, derived by swapping /roster for /schedule in
each team's already-verified roster_url, then confirmed with a live HTTP
check) into Xano via admin/canonical/teams/set-schedule-url.

Usage:
  python push_schedule_urls.py --api-base https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y --token none
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import requests

HERE = Path(__file__).parent
BATCH_SIZE = 200


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--api-base", required=True)
    ap.add_argument("--token", default="none")
    args = ap.parse_args()

    payload = json.loads((HERE / "schedule_url_payload.json").read_text(encoding="utf-8"))
    print(f"pushing {len(payload)} schedule_url updates...")

    total_updated = 0
    total_errors = 0
    for i in range(0, len(payload), BATCH_SIZE):
        batch = payload[i:i + BATCH_SIZE]
        resp = requests.post(
            f"{args.api_base}/admin/canonical/teams/set-schedule-url",
            json={"teams": batch},
            headers={"Authorization": f"Bearer {args.token}"},
            timeout=180,
        )
        if resp.status_code >= 400:
            print(f"  batch {i // BATCH_SIZE + 1} FAILED: HTTP {resp.status_code} - {resp.text[:500]}")
            continue
        data = resp.json()
        total_updated += data.get("updated_count", 0)
        total_errors += data.get("error_count", 0)
        print(f"  batch {i // BATCH_SIZE + 1}: {data.get('updated_count', 0)} updated, {data.get('error_count', 0)} errors")
        if data.get("errors"):
            for err in data["errors"][:5]:
                print(f"      error: {err}")
        time.sleep(0.2)

    print(f"done: {total_updated} updated, {total_errors} errors")


if __name__ == "__main__":
    main()

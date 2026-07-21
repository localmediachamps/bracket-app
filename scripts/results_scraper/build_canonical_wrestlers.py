"""build_canonical_wrestlers.py — first-pass canonical_wrestler/canonical_team
linking, per Garrett's confirmed approach (2026-07-21):
  - Group by exact (name, school) pairs, combined across all seasons - one
    canonical_wrestler per group. A wrestler who transfers schools gets a
    second canonical_wrestler row under the new school; not solved here,
    fixable later via an admin merge tool.
  - display_name + team only for now - no birthdate/legal name backfill,
    that data isn't in the scraped match history anyway.

Reads all 4 local season CSVs (already-imported match history, same schema),
builds the unique (name, school) -> canonical_wrestler mapping and the
unique school -> canonical_team mapping, and writes them out as JSON for the
next step (pushing to Xano + backfilling wrestler_match_history's
winner/loser_canonical_wrestler_id).

Does NOT touch the database - pure local analysis. Run push_canonical.py
(separate script) afterward to actually create the rows.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

HERE = Path(__file__).parent
CSVS = [
    HERE / "ncaa_d1_matches.csv",              # 2025-26
    HERE / "ncaa_d1_matches_2024_25.csv",       # 2024-25
    HERE / "ncaa_d1_matches_2023_24_rescrape.csv",  # 2023-24
    HERE / "ncaa_d1_matches_2022_23.csv",       # 2022-23
]


def norm(s: str | None) -> str:
    return " ".join((s or "").split()).strip()


def main() -> int:
    wrestler_keys: dict[tuple[str, str], int] = {}  # (name, school) -> count
    teams: dict[str, int] = {}  # school -> count
    total_rows = 0

    for csv_path in CSVS:
        if not csv_path.exists():
            print(f"  WARNING: missing {csv_path.name}, skipping")
            continue
        with open(csv_path, encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        print(f"{csv_path.name}: {len(rows)} rows")
        total_rows += len(rows)
        for r in rows:
            for name_field, school_field in (
                ("winner_name_raw", "winner_school_raw"),
                ("loser_name_raw", "loser_school_raw"),
            ):
                name = norm(r.get(name_field))
                school = norm(r.get(school_field))
                if not name or not school:
                    continue
                key = (name, school)
                wrestler_keys[key] = wrestler_keys.get(key, 0) + 1
                teams[school] = teams.get(school, 0) + 1

    print(f"\ntotal match rows processed: {total_rows}")
    print(f"unique (name, school) wrestler pairs: {len(wrestler_keys)}")
    print(f"unique schools: {len(teams)}")

    wrestlers_out = [
        {"display_name": name, "team_name": school, "match_count": count}
        for (name, school), count in sorted(wrestler_keys.items())
    ]
    teams_out = [
        {"name": school, "match_count": count}
        for school, count in sorted(teams.items())
    ]

    (HERE / "canonical_wrestlers_pending.json").write_text(
        json.dumps(wrestlers_out, indent=None), encoding="utf-8"
    )
    (HERE / "canonical_teams_pending.json").write_text(
        json.dumps(teams_out, indent=None), encoding="utf-8"
    )
    print(f"\nwrote canonical_wrestlers_pending.json ({len(wrestlers_out)} wrestlers)")
    print(f"wrote canonical_teams_pending.json ({len(teams_out)} teams)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

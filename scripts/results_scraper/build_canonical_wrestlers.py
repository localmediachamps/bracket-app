"""build_canonical_wrestlers.py — canonical_wrestler/canonical_team identity
linking, per Garrett's confirmed approach (2026-07-22, supersedes the
2026-07-21 (name, school) 1:1 version):

  - ONE canonical_wrestler row per real person, linked to every D1 school
    they've actually competed for via the many-to-many canonical_wrestler_team
    join table (season_label per link) - transfers are extremely common
    (NIL-driven moves after a breakout season, grad-transfers using a final
    year of eligibility elsewhere) and are NOT a new identity.
  - Two same-named entries are treated as DIFFERENT people (not merged) only
    when the name shows up at 2+ DIFFERENT D1 schools in the SAME season with
    genuinely comparable match counts at each - a real transfer never
    produces two active schools in one season, so a same-season split is
    either two people, or (very common in practice) a stray mislabeled row;
    see the majority-count check below for telling those apart. Each side of
    a genuine same-season split is then tracked as its own continuing
    "thread" in later seasons (matched by which school it stays at, or by
    unambiguous 1-to-1 continuation when it transfers) - see build_identities.
  - Class-year (Fr./So./Jr./Sr., redshirt variants) was tried as a second
    splitting signal (to catch "graduated senior vs. new same-named
    freshman") but DROPPED after finding it's genuinely unreliable in the
    scraped data - e.g. a real, single, continuously-enrolled Penn State
    wrestler (confirmed via match volume: 21 matches one season, 27 the
    next, same school, no gap) shows up tagged "Sr." one season and
    "RS Fr." the next. That's a scraper/tagging inconsistency, not a real
    regression, and using it as a hard split trigger produced false splits.
    Not solved here - same-name, non-overlapping-season, no-school-conflict
    cases default to being merged as one person (the far more common real
    pattern), fixable later via an admin merge/split tool if a genuine
    graduated-then-new-freshman collision is found.
  - display_name + legal_first_name/legal_last_name (split from display_name)
    only - no birthdate, no external ids; not available in the scraped
    match history. gender is a constant ("M") at push time, not per-record
    here - this whole dataset is D1 men's wrestling only.

Reads all 4 local season CSVs plus the 4 missing5_matches_*.csv files
(results_scraper_bundle/ - the extra crawl for the 5 D1 schools missing from
the original team-id lists), resolves identities as above, and writes:
  - canonical_wrestlers_pending.json: one entry per resolved PERSON, with
    display_name/legal_first_name/legal_last_name and a team_links list
    ({team_name, season_label, match_count}) for the join table.
  - canonical_teams_pending.json: unique D1 school list (unchanged shape).
  - identity_backfill_map.json: {f"{name}|||{season_label}": identity_index}
    - lets push_canonical.py's backfill phase resolve each raw match row
      (which only has name + season, not which split identity) to the
      right canonical_wrestler_id, since same-season conflicts are already
      resolved to a single identity per (name, season) at this point.

Does NOT touch the database - pure local analysis. Run push_canonical.py
(separate script) afterward to actually create the rows.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

HERE = Path(__file__).parent
BUNDLE = HERE.parent.parent / "results_scraper_bundle"

# (path, season_label) - season_label drives both the join table and the
# class-year-progression identity check, so every source needs one.
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
SEASON_ORDER = {"2022-23": 0, "2023-24": 1, "2024-25": 2, "2025-26": 3}

D1_TEAM_CSV = BUNDLE / "ncaa_d1_team_ids_2024_25.csv"

# Raw scraped spelling -> canonical D1 name, for the two confirmed splits.
SCHOOL_ALIASES = {
    "Presbyterian College": "Presbyterian",
    "sacred heart": "Sacred Heart",
}

# Same-season, multi-school conflict: if the smaller school's match count is
# this much smaller than the larger one (or has this few matches outright),
# treat it as a mislabeled row rather than a second real person.
MAJORITY_RATIO = 3
MAJORITY_MIN_ABSOLUTE = 3  # a minority side with <= this many matches is noise


def norm(s: str | None) -> str:
    return " ".join((s or "").split()).strip()


def load_d1_names() -> set[str]:
    with open(D1_TEAM_CSV, encoding="utf-8") as f:
        return {norm(row["team_name"]) for row in csv.DictReader(f)}


def split_legal_name(display_name: str) -> tuple[str, str]:
    parts = display_name.split(" ", 1)
    if len(parts) == 1:
        return parts[0], ""
    return parts[0], parts[1]


def resolve_season_conflicts(season_schools: dict[str, dict[str, int]]):
    """For one name: {season: {school: count}} -> (resolved, conflicts).

    resolved: {season: single school} - either there was only one school
    that season, or one school dominated the match count and the other
    school's rows are treated as a stray mislabeling, not a second person.
    conflicts: {season: {school: count}} - genuinely comparable match counts
    at 2+ schools the same season: two real people were actually active.
    """
    resolved: dict[str, str] = {}
    conflicts: dict[str, dict[str, int]] = {}
    for season, schools in season_schools.items():
        if len(schools) == 1:
            resolved[season] = next(iter(schools))
            continue
        ranked = sorted(schools.items(), key=lambda kv: -kv[1])
        (top_school, top_n), (_, second_n) = ranked[0], ranked[1]
        if second_n <= MAJORITY_MIN_ABSOLUTE or top_n >= MAJORITY_RATIO * second_n:
            resolved[season] = top_school
        else:
            conflicts[season] = schools
    return resolved, conflicts


def build_identities(name: str, appearances: list[dict]) -> list[dict]:
    """appearances: list of {season, school, class_year, count} (pre-alias,
    pre-D1-filter, already narrowed to this name). Returns a list of resolved
    identities, each: {seasons: {season: school}, team_links: [...]}.

    Each identity is a "thread" tracked chronologically across seasons. A
    thread continues into the next season if its school is still active
    that season (staying put), or - when it transfers - by unambiguous 1-to-1
    matching: if exactly one thread wasn't otherwise extended this season and
    exactly one school is left unclaimed, that's a transfer, not a new
    person. A genuine same-season conflict (2+ schools, comparable counts)
    starts one new thread per school, since no single real person can be
    active at two schools in the same season.
    """
    season_schools: dict[str, dict[str, int]] = {}
    for a in appearances:
        season_schools.setdefault(a["season"], {}).setdefault(a["school"], 0)
        season_schools[a["season"]][a["school"]] += a["count"]

    resolved, conflicts = resolve_season_conflicts(season_schools)

    season_entries: dict[str, dict[str, int]] = {}
    for season, school in resolved.items():
        season_entries[season] = {school: season_schools[season][school]}
    for season, schools in conflicts.items():
        season_entries[season] = dict(schools)

    ordered_seasons = sorted(season_entries.keys(), key=lambda s: SEASON_ORDER.get(s, 99))

    threads: list[dict] = []  # each: {"seasons": {season: school}, "last_school": str}

    for season in ordered_seasons:
        remaining = dict(season_entries[season])  # school -> count, consumed as claimed

        # Pass 1: a thread continues if its current school is active this season.
        for t in threads:
            school = t["last_school"]
            if school in remaining:
                t["seasons"][season] = school
                del remaining[school]

        # Pass 2: leftover schools this season need a thread. Unambiguous
        # 1-to-1 (one thread not yet extended, one school left) = a transfer.
        # Anything ambiguous (0 or 2+ on either side) starts fresh threads -
        # erring toward splitting rather than guessing a risky merge.
        if remaining:
            waiting = [t for t in threads if season not in t["seasons"]]
            leftover_schools = list(remaining.keys())
            if len(leftover_schools) == 1 and len(waiting) == 1:
                t = waiting[0]
                school = leftover_schools[0]
                t["seasons"][season] = school
                t["last_school"] = school
            else:
                for school in leftover_schools:
                    threads.append({"seasons": {season: school}, "last_school": school})

    out = []
    for t in threads:
        links: dict[tuple[str, str], dict] = {}
        for season, school in t["seasons"].items():
            count = season_schools[season][school]
            links[(school, season)] = {"team_name": school, "season_label": season, "match_count": count}
        out.append({"seasons": t["seasons"], "team_links": list(links.values())})
    return out


def main() -> int:
    d1_names = load_d1_names()
    print(f"loaded {len(d1_names)} D1 team names from {D1_TEAM_CSV.name}")

    # name -> {(season, school): count}
    raw: dict[str, dict[tuple[str, str], int]] = {}
    total_rows = 0
    skipped_non_d1 = 0

    for csv_path, season in SEASON_CSVS:
        if not csv_path.exists():
            print(f"  WARNING: missing {csv_path.name}, skipping")
            continue
        with open(csv_path, encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        print(f"{csv_path.name} ({season}): {len(rows)} rows")
        total_rows += len(rows)
        for r in rows:
            for name_f, school_f in (
                ("winner_name_raw", "winner_school_raw"),
                ("loser_name_raw", "loser_school_raw"),
            ):
                name = norm(r.get(name_f))
                school = norm(r.get(school_f))
                if not name or not school:
                    continue
                school = SCHOOL_ALIASES.get(school, school)
                if school not in d1_names:
                    skipped_non_d1 += 1
                    continue
                key = (season, school)
                bucket = raw.setdefault(name, {})
                bucket[key] = bucket.get(key, 0) + 1

    print(f"\ntotal match rows processed: {total_rows}")
    print(f"non-D1 winner/loser sides skipped: {skipped_non_d1}")
    print(f"unique raw D1 names: {len(raw)}")

    wrestlers_out = []
    identity_backfill_map: dict[str, int] = {}  # "name|||season" -> index into wrestlers_out
    teams_seen: dict[str, int] = {}
    split_name_count = 0

    for name in sorted(raw):
        appearances = [
            {"season": season, "school": school, "count": count}
            for (season, school), count in raw[name].items()
        ]
        identities = build_identities(name, appearances)
        if len(identities) > 1:
            split_name_count += 1

        legal_first, legal_last = split_legal_name(name)
        for ident in identities:
            idx = len(wrestlers_out)
            # Keyed by (name, season, school) - not just (name, season) - since
            # a genuine same-season conflict has 2+ identities sharing a
            # season, disambiguated only by which school each row shows.
            for season, school in ident["seasons"].items():
                identity_backfill_map[f"{name}|||{season}|||{school}"] = idx
            for link in ident["team_links"]:
                teams_seen[link["team_name"]] = teams_seen.get(link["team_name"], 0) + link["match_count"]
            # most recent season's school, for canonical_wrestler.current_team_id
            latest_season = max(ident["seasons"], key=lambda s: SEASON_ORDER.get(s, 99))
            wrestlers_out.append({
                "display_name": name,
                "legal_first_name": legal_first,
                "legal_last_name": legal_last,
                "current_team_name": ident["seasons"][latest_season],
                "team_links": ident["team_links"],
            })

    print(f"resolved wrestler identities: {len(wrestlers_out)} (from {len(raw)} raw names, {split_name_count} names split into 2+ people)")

    # Manual overrides (Garrett, 2026-07-22): the algorithm's same-season
    # conflict split can't distinguish a genuine mid-season transfer from two
    # different people at the season granularity this data has, and can't
    # chain a transfer onward past a second ambiguous season (no signal to
    # know which of several "waiting" threads a new season's school
    # continues). Confirmed by domain knowledge for specific names.
    #   - "Carter Schmidt": one real person, transferred Iowa State ->
    #     Oklahoma mid-2023-24 (merge all identities under this name - only
    #     one real person by this name in the dataset).
    #   - "Patrick Adams": Rutgers' official roster bio confirms one real
    #     person went Buffalo (2021-23) -> Northwestern (2023-25) -> Rutgers
    #     (current) - merge only those 3 identities. The separate "Campbell"
    #     identity is a genuinely different person, confirmed - leave it split.
    MANUAL_MERGES: list[tuple[str, set[str] | None]] = [
        ("Carter Schmidt", None),  # None = merge all identities under this name
        ("Patrick Adams", {"Buffalo", "Northwestern", "Rutgers"}),
    ]
    for name, schools_filter in MANUAL_MERGES:
        idxs = [
            i for i, w in enumerate(wrestlers_out)
            if w["display_name"] == name
            and (schools_filter is None or any(l["team_name"] in schools_filter for l in w["team_links"]))
        ]
        if len(idxs) < 2:
            continue
        keep_idx = idxs[0]
        merged_links: dict[tuple[str, str], dict] = {
            (l["team_name"], l["season_label"]): l for l in wrestlers_out[keep_idx]["team_links"]
        }
        for i in idxs[1:]:
            for l in wrestlers_out[i]["team_links"]:
                merged_links[(l["team_name"], l["season_label"])] = l
        wrestlers_out[keep_idx]["team_links"] = list(merged_links.values())
        latest = max(merged_links.values(), key=lambda l: SEASON_ORDER.get(l["season_label"], 99))
        wrestlers_out[keep_idx]["current_team_name"] = latest["team_name"]

        drop_idxs = set(idxs[1:])
        remap = {}
        new_pos = 0
        for i in range(len(wrestlers_out)):
            if i in drop_idxs:
                continue
            remap[i] = new_pos
            new_pos += 1
        for k in list(identity_backfill_map.keys()):
            old_idx = identity_backfill_map[k]
            if old_idx in drop_idxs:
                identity_backfill_map[k] = remap[keep_idx]
            else:
                identity_backfill_map[k] = remap[old_idx]
        wrestlers_out = [w for i, w in enumerate(wrestlers_out) if i not in drop_idxs]
        print(f"  manual merge: {name} ({len(idxs)} identities -> 1)")

    print(f"unique schools referenced: {len(teams_seen)}")

    teams_out = [{"name": name, "match_count": count} for name, count in sorted(teams_seen.items())]

    (HERE / "canonical_wrestlers_pending.json").write_text(
        json.dumps(wrestlers_out, indent=None), encoding="utf-8"
    )
    (HERE / "canonical_teams_pending.json").write_text(
        json.dumps(teams_out, indent=None), encoding="utf-8"
    )
    (HERE / "identity_backfill_map.json").write_text(
        json.dumps(identity_backfill_map, indent=None), encoding="utf-8"
    )
    print(f"\nwrote canonical_wrestlers_pending.json ({len(wrestlers_out)} identities)")
    print(f"wrote canonical_teams_pending.json ({len(teams_out)} teams)")
    print(f"wrote identity_backfill_map.json ({len(identity_backfill_map)} name|||season keys)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

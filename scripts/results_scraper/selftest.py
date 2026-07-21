#!/usr/bin/env python3
"""selftest.py — offline self-test for the results scraper package.

Synthesizes two small fake EventMatches pages (one "summary column" layout,
one "separate columns" layout) with one overlapping bout across both team
pages, runs the real parse -> normalize -> dedupe pipeline against a temp
cache dir, and asserts the expected outcomes. Makes NO network calls.

Run:  python scripts/results_scraper/selftest.py
Exit code 0 = pass, 1 = failure.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import event_scraper as tw
import scrape_client as twclient
import normalize as twnormalize
import event_match_parser as twparse

SEASON = "9990000000"
EVENT = "8880000000"

# --- Fake page A: "summary" layout (Weight | Summary), team 111 -------------
PAGE_A = """<html><head><title>Event Matches</title></head><body>
<table border="1">
  <tr><th>Weight</th><th>Summary</th></tr>
  <tr><td colspan="2">Champ. Round 1</td></tr>
  <tr><td>125</td><td>Spencer Lee (Penn State) 24-0, Jr. over Nick Suriano (Rutgers) 19-2, Sr. (Dec 7-2)</td></tr>
  <tr><td>133</td><td>Roman Bravo-Young (Penn State) 20-1, Jr. over Daton Fix (Oklahoma State) 18-1, Sr. (MD 10-2)</td></tr>
  <tr><td>141</td><td>Nick Lee (Penn State) W Jaydin Eierman (Iowa), 5-3 Dec</td></tr>
  <tr><td>149</td><td>Yianni Diakomihalis (Cornell) over Sammy Sasso (Ohio State) (Fall 4:22)</td></tr>
</table>
</body></html>"""

# --- Fake page B: "columns" layout (Weight|Winner|Loser|Score|Result|Round),
# --- team 222. Includes the SAME 133 bout (dedupe target) and one malformed
# --- row (157, all fields empty except "TBD").
PAGE_B = """<html><head><title>Event Matches</title></head><body>
<table border="1">
  <tr><th>Weight</th><th>Winner</th><th>Loser</th><th>Score</th><th>Result</th><th>Round</th></tr>
  <tr><td>133</td><td>Roman Bravo-Young (Penn State)</td><td>Daton Fix (Oklahoma State)</td><td>10-2</td><td>MD</td><td>Champ. Round 1</td></tr>
  <tr><td>165</td><td><b>Alex Marinelli (Iowa)</b></td><td>Evan Wick (Cal Poly)</td><td>8-5</td><td>Dec</td><td>Champ. Round 1</td></tr>
  <tr><td>285</td><td>Gable Steveson (Minnesota)</td><td>Mason Parris (Michigan)</td><td>17-2</td><td>TF</td><td>Champ. Round 1</td></tr>
  <tr><td>157</td><td></td><td></td><td></td><td>TBD</td><td>Champ. Round 1</td></tr>
</table>
</body></html>"""

TEAM_LINKS_HTML = """<html><body>
<a href="https://www.trackwrestling.com/seasons/EventMatches.jsp?seasonId=1560238138&eventId=8710102132&teamId=758803150&tournamentId=931299132">Cornell, NY</a>
<a href="https://www.trackwrestling.com/seasons/EventMatches.jsp?seasonId=1560238138&eventId=8710102132&teamId=758850150&tournamentId=931299132">Penn State, PA</a>
</body></html>"""


def _seed_cache(cache_dir: str) -> None:
    pages = [("111", "Penn State", PAGE_A), ("222", "Oklahoma State", PAGE_B)]
    index = {}
    for team_id, team_name, html in pages:
        key = twclient.cache_key(SEASON, EVENT, team_id)
        twclient.cache_file(cache_dir, key).write_text(html, encoding="utf-8")
        index[key] = {
            "season_id": SEASON,
            "event_id": EVENT,
            "team_id": team_id,
            "team_name": team_name,
            "fetched_at": 0,
        }
    twclient.save_index(cache_dir, index)


def main() -> int:
    checks = []

    def check(name: str, cond: bool, detail: str = ""):
        checks.append((name, cond, detail))
        print(f"  {'PASS' if cond else 'FAIL'}  {name}{(' — ' + detail) if detail else ''}")

    print("== unit: victory type mapping ==")
    for raw, expected in [
        ("Dec 7-2", "decision"), ("MD 10-2", "major"), ("TF 17-2", "tech_fall"),
        ("Fall 4:22", "fall"), ("Inj. 2:10", "injury_default"), ("DQ", "disqualification"),
        ("MFF", "medical_forfeit"), ("For.", "forfeit"), ("SV-1 3-1", "decision"),
    ]:
        got = twparse.normalize_victory_type(raw)
        check(f"victory '{raw}' -> {expected}", got == expected, f"got {got}")

    print("== unit: weight normalization ==")
    check("HWT -> 285", twnormalize.normalize_weight("HWT") == "285")
    check("Heavyweight -> 285", twnormalize.normalize_weight("Heavyweight") == "285")
    check("125 lbs -> 125", twnormalize.normalize_weight("125 lbs") == "125")
    check("149 -> 149", twnormalize.normalize_weight("149") == "149")

    print("== unit: team-link extraction ==")
    teams = tw.extract_team_ids(TEAM_LINKS_HTML, source_name="Test")
    check("extracted 2 teams", len(teams) == 2, f"got {len(teams)}")
    check(
        "cornell row correct",
        any(t["team_id"] == "758803150" and t["team_name"] == "Cornell"
            and t["state"] == "NY" and t["season_id"] == "1560238138"
            and t["tournament_id"] == "931299132" for t in teams),
    )

    print("== pipeline: parse + normalize + dedupe ==")
    with tempfile.TemporaryDirectory() as cache_dir:
        _seed_cache(cache_dir)
        candidates, report = tw.parse_cached_event(cache_dir, EVENT, occurred_at="2026-03-19")

        check(">=6 rows parsed", report["total_rows"] >= 6, f"rows={report['total_rows']}")
        # 8 raw rows (4 + 4); the 133 bout appears on both pages -> 7 unique.
        check("dedupe to 7 unique matches", report["unique_matches"] == 7,
              f"unique={report['unique_matches']}")
        check("exactly 1 duplicate merged", report["duplicates_merged"] == 1,
              f"merged={report['duplicates_merged']}")
        check("no false conflicts", len(report["conflicts"]) == 0,
              f"conflicts={len(report['conflicts'])}")

        vtypes = {c["source_victory_type"] for c in candidates}
        for expected in ("decision", "major", "tech_fall", "fall"):
            check(f"victory type present: {expected}", expected in vtypes,
                  f"types={sorted(t for t in vtypes if t)}")

        by_weight = {}
        for c in candidates:
            by_weight.setdefault(c["source_weight_class"], []).append(c)

        w125 = by_weight.get("125", [{}])[0]
        check("125 winner", w125.get("source_winner") == "Spencer Lee",
              f"got {w125.get('source_winner')}")
        check("125 winner school", w125.get("source_winner_school") == "Penn State")
        check("125 loser school", w125.get("source_loser_school") == "Rutgers")
        check("125 score", w125.get("source_score") == "7-2", f"got {w125.get('source_score')}")
        check("125 confidence 1.0", w125.get("extraction_confidence") == 1.0)
        check("125 round", (w125.get("source_round") or "") == "Champ. Round 1")
        check("125 occurred_at", w125.get("occurred_at") == "2026-03-19")

        w149 = by_weight.get("149", [{}])[0]
        check("149 fall with time score", w149.get("source_score") == "4:22"
              and w149.get("source_victory_type") == "fall")

        w157 = by_weight.get("157", [{}])[0]
        check("malformed row captured, no invented winner",
              w157.get("source_winner") is None and w157.get("source_loser") is None)
        check("malformed row confidence 0.4",
              w157.get("extraction_confidence") == 0.4)
        check("raw_fragment retained on malformed row",
              bool(w157.get("raw_fragment")))

        check("all candidates have 16-char keys",
              all(len(c["external_match_key"]) == 16 for c in candidates))
        check("keys unique",
              len({c["external_match_key"] for c in candidates}) == len(candidates))

        # JSON round-trip (what `parse --out` writes).
        blob = json.dumps(candidates)
        check("candidates JSON-serializable", len(json.loads(blob)) == len(candidates))

    print("== unit: conflict detection ==")
    r1 = twparse.MatchRecord(
        weight_text="174", winner="Carter Starocci", loser="Mekhi Lewis",
        score="4-1", victory_type="decision", round_text="Champ. Round 1",
        extraction_confidence=1.0, team_id="111",
    )
    r2 = twparse.MatchRecord(
        weight_text="174", winner="Mekhi Lewis", loser="Carter Starocci",
        score=None, victory_type=None, round_text="Champ. Round 1",
        extraction_confidence=0.7, team_id="222",
    )
    cands, rep = twnormalize.dedupe([r1, r2], EVENT)
    check("conflicting winners -> 1 unique", rep["unique_matches"] == 1)
    check("conflict flagged", len(rep["conflicts"]) == 1)
    check("higher-confidence record kept",
          cands[0]["source_winner"] == "Carter Starocci")

    failed = [c for c in checks if not c[1]]
    print(f"\n{'SELFTEST PASSED' if not failed else 'SELFTEST FAILED'}: "
          f"{len(checks) - len(failed)}/{len(checks)} checks")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())

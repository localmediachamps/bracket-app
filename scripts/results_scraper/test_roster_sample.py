"""Ad-hoc validation of twroster against a real captured Arizona State
roster (fixtures/roster_sample.json - extracted from a live page, 2026-07-20).
Not part of selftest.py yet - promote once the fetch side (session/cookie
handling for the roster page) is also built."""

import json
import sys

from roster_parser import parse_roster

path = sys.argv[1] if len(sys.argv) > 1 else "fixtures/roster_sample.json"
with open(path, encoding="utf-8") as f:
    rows = json.load(f)

roster = parse_roster(rows)
print(f"parsed {len(roster)} wrestlers")
for w in roster:
    print(f"  {w.wrestler_id} {w.first_name} {w.last_name} ({w.class_year}) {w.weight} lbs - {w.team_name}")

assert len(roster) == 33, f"expected 33 wrestlers, got {len(roster)}"
kyler = next(w for w in roster if w.wrestler_id == "34944528132")
assert kyler.first_name == "Kyler" and kyler.last_name == "Larkin"
assert kyler.team_name == "Arizona State"
assert kyler.weight == "133"
assert kyler.class_year == "Fr."
assert all(w.team_id == "758764150" for w in roster), "all wrestlers should share the same team_id"
assert len({w.wrestler_id for w in roster}) == 33, "wrestler ids should be unique"

print("\nALL CHECKS PASSED")

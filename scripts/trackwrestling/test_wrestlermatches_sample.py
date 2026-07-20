"""Ad-hoc validation of twwrestlermatches against the real Kyler Larkin sample
captured 2026-07-20 (fixtures/wrestler_matches_sample.json). Not part of
selftest.py yet - promote once the fetch side (session/cookie handling for
AjaxFunctions.jsp) is also built."""

import json
import sys

from twwrestlermatches import parse_wrestler_matches_response, to_candidate

with open(sys.argv[1] if len(sys.argv) > 1 else "fixtures/wrestler_matches_sample.json") as f:
    rows = json.load(f)

matches = parse_wrestler_matches_response(rows)
print(f"parsed {len(matches)} rows")

byes = [m for m in matches if m.is_bye]
duals = [m for m in matches if m.event_type == "dual" and not m.is_bye]
tourneys = [m for m in matches if m.event_type == "tournament" and not m.is_bye]
print(f"  byes={len(byes)} duals={len(duals)} tournament matches={len(tourneys)}")

for m in matches:
    tag = "BYE" if m.is_bye else f"{m.winner_name} ({m.winner_school}) over {m.loser_name} ({m.loser_school})"
    round_part = f" [{m.round_label}]" if m.round_label else ""
    print(f"  {m.date_start} {m.event_name!r}{round_part} {m.weight} {m.victory_type_abbrev}: {tag}")

candidates = [c for m in matches if (c := to_candidate(m)) is not None]
assert len(candidates) == len(matches) - len(byes), "candidate count should exclude only byes"
assert all(c["extraction_confidence"] == 1.0 for c in candidates)

# Sanity: known intra-squad match (row 0) - both schools equal
intra = matches[0]
assert intra.winner_school == intra.loser_school == "Arizona State"
assert intra.winner_name == "Carter Dibert" and intra.loser_name == "Kyler Larkin"

# Sanity: known medical-forfeit-loss match, Evan Frost beat Kyler
mffl = next(m for m in matches if m.victory_type_abbrev == "MFFL")
assert mffl.winner_name == "Evan Frost" and mffl.loser_name == "Kyler Larkin"

# Sanity: NCAA tournament round labels present and distinct
ncaa_rounds = {m.round_label for m in matches if m.event_series_name == "2026 NCAA Division I Championships"}
assert ncaa_rounds == {"Champ. Round 1", "Champ. Round 2", "Quarterfinals", "Cons. Round 4"}, ncaa_rounds

print(f"\nbuilt {len(candidates)} candidates (excluded {len(byes)} byes)")
print("ALL CHECKS PASSED")

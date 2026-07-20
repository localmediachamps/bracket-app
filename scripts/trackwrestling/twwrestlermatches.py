"""twwrestlermatches.py — parser for Trackwrestling's team-centric match data.

Discovered 2026-07-20: TeamPage > Matches > Results per Wrestler does NOT
render match data server-side. The page loads an empty grid, then fires
  GET /seasons/AjaxFunctions.jsp?...&function=getWrestlerMatches&wrestlerIds=<id>[,<id>...]
which returns a raw JSON array-of-arrays (one row per match). The page's own
JS (dataGrid[row][N] indexing, see WrestlerMatches.jsp source) was used to
reverse-engineer and cross-verify every field index below against 27 real
matches spanning dual meets, tournaments, byes, forfeits, a medical default,
and an intra-squad wrestle-off.

This is a fundamentally better source than the original EventMatches.jsp
per-event/per-team HTML scrape:
  - One request returns a wrestler's ENTIRE SEASON (dual meets + every
    tournament), not just one event.
  - wrestlerIds accepts a comma-separated list, so a whole team roster's
    matches for the season can likely be fetched in one call (untested at
    scale as of this writing).
  - Clean structured JSON, not heuristic HTML-table parsing.
  - Winner is always the "A" wrestler (fields 14/16/17/18/19/39), loser is
    always "B" (fields 15/20/21/22/23/40) - NOT dependent on which wrestler
    the query was made for. Confirmed against a match this wrestler lost.

Row field index map (0-based):
  0  match id (this site's internal id, stable per bout)
  1  weight
  2  victory type code (numeric, e.g. 1=fall, 2=tech fall, 3=major dec,
     4=decision, 5=forfeit, 0=bye, 38=medical forfeit w/loss)
  3  victory type name, Title Case ("Technical Fall", "Major Decision", ...)
  4  victory type abbreviation ("TF", "MD", "Dec", "Fall", "Bye", "For.")
  5  summary template ("[winner] over [loser] ([wtAbbr] [score] [fallTime])")
  6-13  score/period detail fields (not parsed here - see NOTE below)
  14 winner wrestler id            27 winner short id (legacy numeric id)
  15 loser wrestler id             28 loser short id
  16 winner first name             29 constant ("2" typically)
  17 winner last name              30 query-subject wrestler id (constant
  18 winner school (full)             across every row in one response -
  19 winner school abbrev             i.e. whichever wrestlerIds you asked for)
  20 loser first name              31 round label or None for dual meets
  21 loser last name                  ("Champ. Round 1", "Quarterfinals",
  22 loser school (full)              "Semifinals", "1st Place Match",
  23 loser school abbrev              "Cons. Round 4", ...)
  24 victory type, "Tech. Fall" style  32 unclear (day number within a
  25 victory type, lowercase              multi-day event?) - not used
  26 constant ("1")                  33 round chronological sort key (decimal
                                          string, e.g. "1.0".."66.0") or None
  34 constant ("")                   35 level label ("Varsity") or None
  36 date start (YYYYMMDD or YYYYMMDDHHmm - format varies)
  37 date end (same format; multi-day events differ from start)
  38 event name - THE SPECIFIC matchup label (e.g. "vs. Arizona State",
     "Michigan State Open", "2026 NCAA Division I Championships")
  39 winner wrestler id (duplicate of 14, used for the hyperlink)
  40 loser wrestler id (duplicate of 15)
  41 result-recorded timestamp, or None
  42 event id (Trackwrestling's numeric event id - matches the event-index
     CSVs already in trackwrestling_scraping_bundle/)
  43 event dual/individual flag: "0" = dual meet, "1" = individual/tournament
  44 event category letter: "D" = dual, "I" = individual (redundant w/ 43)
  45 query-subject last name (constant)   52 winner class year (Fr./So./...)
  46 query-subject first name (constant)  53 winner team id
  47 constant ("2")                       54 winner team abbrev
  48 weight (duplicate of 1)               55 winner team state
  49 score-only template (like 5 minus     56 loser class year
     the "[winner] over [loser]" prefix)   57 loser team id
  50 constant ("")                         58 loser team abbrev
  51 PARENT event/series name (e.g. "Dual" 59 loser team state
     for a standalone dual, or the         60 winner secondary id (purpose
     invitational name for a dual that's       unconfirmed, e.g. conference id)
     part of a bigger dual tournament)     61 loser secondary id (same)

NOTE on score fields (6-13): not parsed into a structured score here. The
templates in field 5/49 (e.g. "[wtAbbr] [score] [fallTime]") combined with
raw period/point fields would let a future pass reconstruct a numeric score
string, but round/winner/loser/victory-type/event context (what this module
extracts) covers everything needed for external_result_candidate rows today.
Revisit if points-based scoring detail becomes a requirement.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class WrestlerMatch:
    match_id: str
    weight: Optional[str]
    victory_type_code: Optional[str]
    victory_type: Optional[str]  # Title Case, e.g. "Technical Fall"
    victory_type_abbrev: Optional[str]
    is_bye: bool

    winner_id: Optional[str]
    winner_name: Optional[str]
    winner_school: Optional[str]
    winner_school_abbrev: Optional[str]
    winner_class_year: Optional[str]
    winner_team_id: Optional[str]

    loser_id: Optional[str]
    loser_name: Optional[str]
    loser_school: Optional[str]
    loser_school_abbrev: Optional[str]
    loser_class_year: Optional[str]
    loser_team_id: Optional[str]

    round_label: Optional[str]
    round_sort_key: Optional[str]
    level: Optional[str]

    date_start: Optional[str]
    date_end: Optional[str]

    event_id: Optional[str]
    event_name: Optional[str]  # specific matchup label
    event_series_name: Optional[str]  # parent tournament/dual-series name
    event_type: Optional[str]  # "dual" | "tournament"

    query_subject_id: Optional[str]

    raw_row: list = field(default_factory=list, repr=False)


def _s(row: list, idx: int) -> Optional[str]:
    """Safe string-or-None accessor (rows can be shorter, e.g. bye rows)."""
    if idx >= len(row):
        return None
    v = row[idx]
    return None if v is None else str(v)


def parse_wrestler_matches_response(rows: list) -> list[WrestlerMatch]:
    """Parse the raw getWrestlerMatches JSON array into WrestlerMatch records.

    Includes bye rows (is_bye=True, no loser) - callers building
    external_result_candidate rows should filter these out, since a bye
    isn't a result against an opponent.
    """
    out: list[WrestlerMatch] = []
    for row in rows:
        vtype_code = _s(row, 2)
        is_bye = vtype_code == "0" or _s(row, 3) == "Bye"
        dual_flag = _s(row, 43)
        event_type = "dual" if dual_flag == "0" else "tournament" if dual_flag == "1" else None

        out.append(
            WrestlerMatch(
                match_id=_s(row, 0) or "",
                weight=_s(row, 1),
                victory_type_code=vtype_code,
                victory_type=_s(row, 3),
                victory_type_abbrev=_s(row, 4),
                is_bye=is_bye,
                winner_id=_s(row, 14),
                winner_name=f"{_s(row, 16) or ''} {_s(row, 17) or ''}".strip() or None,
                winner_school=_s(row, 18),
                winner_school_abbrev=_s(row, 19),
                winner_class_year=_s(row, 52),
                winner_team_id=_s(row, 53),
                loser_id=_s(row, 15),
                loser_name=f"{_s(row, 20) or ''} {_s(row, 21) or ''}".strip() or None,
                loser_school=_s(row, 22),
                loser_school_abbrev=_s(row, 23),
                loser_class_year=_s(row, 56),
                loser_team_id=_s(row, 57),
                round_label=_s(row, 31),
                round_sort_key=_s(row, 33),
                level=_s(row, 35),
                date_start=_s(row, 36),
                date_end=_s(row, 37),
                event_id=_s(row, 42),
                event_name=_s(row, 38),
                event_series_name=_s(row, 51),
                event_type=event_type,
                query_subject_id=_s(row, 30),
                raw_row=row,
            )
        )
    return out


def to_candidate(m: WrestlerMatch) -> Optional[dict]:
    """Shape one WrestlerMatch into an external_result_candidate-like dict.
    Returns None for byes only - a bye means no match happened at all. A
    forfeit win can legitimately have loser_id=None (opponent's team
    forfeited the whole weight, no specific wrestler on record) and is
    still a real result, not excluded here."""
    if m.is_bye:
        return None
    return {
        "external_source_match_id": m.match_id,
        "source_weight_class": m.weight,
        "source_event_id": m.event_id,
        "source_event_name": m.event_name,
        "source_event_series_name": m.event_series_name,
        "source_event_type": m.event_type,
        "source_round": m.round_label,
        "source_round_sort_key": m.round_sort_key,
        "source_level": m.level,
        "source_winner": m.winner_name,
        "source_winner_school": m.winner_school,
        "source_winner_class_year": m.winner_class_year,
        "source_loser": m.loser_name,
        "source_loser_school": m.loser_school,
        "source_loser_class_year": m.loser_class_year,
        "source_victory_type": m.victory_type,
        "date_start": m.date_start,
        "date_end": m.date_end,
        "extraction_confidence": 1.0,
    }

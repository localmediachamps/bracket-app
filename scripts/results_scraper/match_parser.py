"""match_parser.py — parser for the results provider's team-centric match data.

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
  6  **WIN SIDE FLAG: "1" = side A (fields 14/16-19/39/52-55) actually won,
     "2" = side B (fields 15/20-23/40/56-59) actually won.** Fields 14-25
     are just two fixed bracket-position slots ("side A"/"side B"), NOT
     "winner"/"loser" - this flag is what actually determines which side
     won. CRITICAL - see "Winner/loser bug" note below; do not remove this
     field or revert to assuming side A is always the winner.
  7-13  other score/period detail fields (not parsed here - see NOTE below)
  14 side A wrestler id             27 side A short id (legacy numeric id)
  15 side B wrestler id             28 side B short id
  16 side A first name              29 constant ("2" typically)
  17 side A last name               30 query-subject wrestler id (constant
  18 side A school (full)              across every row in one response -
  19 side A school abbrev              i.e. whichever wrestlerIds you asked for)
  20 side B first name              31 round label or None for dual meets
  21 side B last name                  ("Champ. Round 1", "Quarterfinals",
  22 side B school (full)              "Semifinals", "1st Place Match",
  23 side B school abbrev              "Cons. Round 4", ...)
  24 victory type, "Tech. Fall" style  32 unclear (day number within a
  25 victory type, lowercase              multi-day event?) - not used
  26 constant ("1")                  33 round chronological sort key (decimal
                                          string, e.g. "1.0".."66.0") or None
  34 constant ("")                   35 level label ("Varsity") or None
  36 date start (YYYYMMDD or YYYYMMDDHHmm - format varies)
  37 date end (same format; multi-day events differ from start)
  38 event name - THE SPECIFIC matchup label (e.g. "vs. Arizona State",
     "Michigan State Open", "2026 NCAA Division I Championships")
  39 side A wrestler's real/global id (NOT a duplicate of 14 - 14 is a
     per-match participant id, 39 is the stable id matching field 30/the
     roster's wrestler_id - see "Winner/loser bug" note)
  40 side B wrestler's real/global id (same relationship to 15)
  41 result-recorded timestamp, or None
  42 event id (the provider's numeric event id - matches the event-index
     CSVs already in results_scraper_bundle/)
  43 event dual/individual flag: "0" = dual meet, "1" = individual/tournament
  44 event category letter: "D" = dual, "I" = individual (redundant w/ 43)
  45 query-subject last name (constant)   52 side A class year (Fr./So./...)
  46 query-subject first name (constant)  53 side A team id
  47 constant, purpose unconfirmed         54 side A team abbrev
     (NOT always "2" - varies, e.g. "4"    55 side A team state
     seen for one wrestler across all      56 side B class year
     their rows - possibly a per-wrestler  57 side B team id
     or per-query index, not literally a   58 side B team abbrev
     constant despite earlier assumption)  59 side B team state
  48 weight (duplicate of 1)               60 side A secondary id (purpose
  49 score-only template (like 5 minus         unconfirmed, e.g. conference id)
     the "[winner] over [loser]" prefix)   61 side B secondary id (same)
  50 constant ("")
  51 PARENT event/series name (e.g. "Dual"
     for a standalone dual, or the
     invitational name for a dual that's
     part of a bigger dual tournament)

NOTE on score fields (7-13): not parsed into a structured score here. The
templates in field 5/49 (e.g. "[wtAbbr] [score] [fallTime]") combined with
raw period/point fields would let a future pass reconstruct a numeric score
string, but round/winner/loser/victory-type/event context (what this module
extracts) covers everything needed for external_result_candidate rows today.
Revisit if points-based scoring detail becomes a requirement.

WINNER/LOSER BUG (found + fixed 2026-07-20, after a real Air Force scrape
was cross-checked against the provider's own displayed page and found
~70% of decided matches backwards): the original version of this module
assumed "side A" (fields 14/16/17/18/19/39) was ALWAYS the winner and "side
B" (15/20/21/22/23/40) was ALWAYS the loser, based on a small single-wrestler
fixture sample that happened not to expose the bug. Confirmed via an 11-match
Jacob Jones (Air Force, wrestler id 34944189132) real-world sample,
cross-referenced against the provider's own rendered page, that side A
is winner only when field[6]=="1"; when field[6]=="2", side B is the actual
winner and side A actually lost. This is now handled by `_side_a_won()`
below - do not revert to a fixed side-A-is-winner assumption. A handful of
rows (~1%) have field[6]==None (victory type entirely missing/unresolved in
the provider's own data) - these are marked extraction_confidence=0.5 in
to_candidate() since the true winner can't be determined from this field.
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

    # True when field[6] (the win-side flag) was missing/unrecognized, so
    # winner/loser below is a best-effort guess (defaults to side A) rather
    # than a confirmed result - see WINNER/LOSER BUG note above.
    win_side_uncertain: bool = False

    # "winner-loser" bout score, e.g. "16-1" - decoded 2026-07-21 from fields
    # 7/10 (side A/side B point totals, independent of who won - see
    # SCORE/TIME note below). None for a Fall (no numeric score requested)
    # and for administrative no-contest outcomes (bye/forfeit/default/etc).
    score: Optional[str] = None

    # Seconds elapsed when the match ended early (fall, tech fall, injury
    # default, or a fall during a sudden-victory OT period). None when the
    # match went the full scheduled length (decision, major decision, a
    # points-based sudden victory/tie-breaker) - field 13 is 0 in that case.
    time_seconds: Optional[int] = None

    raw_row: list = field(default_factory=list, repr=False)


# Victory types with no meaningful numeric bout score to report: a pin ends
# the match outright (Garrett's explicit call - record time only, not score),
# and these others are administrative outcomes where 0-0 isn't a real score.
_NO_SCORE_VICTORY_TYPES = {
    "Fall", "Bye", "Forfeit", "Medical Forfeit", "Medical FF w/Loss",
    "Default", "Disqualified", "No Contest", "Double Forfeit",
}


def _decode_score_and_time(row: list, side_a_won: bool) -> tuple[Optional[str], Optional[int]]:
    """Decode the bout score ("winner-loser") and early-stoppage time
    (seconds) from fields 7 (side A points), 10 (side B points), and 13
    (stoppage time in seconds, 0 if the match went the full length).

    Reverse-engineered 2026-07-21 against real Decision/Major
    Decision/Technical Fall/Fall rows: field 7/10 margins consistently
    matched each victory type's real point-margin rule (e.g. exactly 15+ for
    Technical Fall, 8-14 for Major Decision), confirming these are the real
    bout score, not an unrelated team-score field. Fields 5/49 ("summary
    template" strings) are NOT usable for this - they're always the raw
    unfilled template text (e.g. "[wtAbbr] [score] [fallTime]"), never
    actually interpolated by this endpoint.
    """
    side_a_pts = _s(row, 7)
    side_b_pts = _s(row, 10)
    winner_pts = side_a_pts if side_a_won else side_b_pts
    loser_pts = side_b_pts if side_a_won else side_a_pts

    vtype_name = _s(row, 3)
    # "(Fall)" suffix covers sudden-victory/tie-breaker periods that ended in
    # a pin (e.g. "Sudden Victory - 1 (Fall)") - still a pin, no score.
    ends_in_fall = vtype_name is not None and vtype_name.endswith("(Fall)")
    score = None
    if (
        vtype_name is not None
        and vtype_name not in _NO_SCORE_VICTORY_TYPES
        and not ends_in_fall
        and winner_pts is not None
        and loser_pts is not None
    ):
        score = f"{winner_pts}-{loser_pts}"

    time_seconds = None
    raw_time = _s(row, 13)
    if raw_time is not None:
        try:
            parsed_time = int(raw_time)
        except ValueError:
            parsed_time = 0
        if parsed_time > 0:
            time_seconds = parsed_time

    return score, time_seconds


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

        # Fields 14-25 are two fixed bracket-position slots ("side A"/"side
        # B"), NOT winner/loser - field[6] says which side actually won.
        # See the WINNER/LOSER BUG note in this module's docstring.
        win_side = _s(row, 6)
        win_side_uncertain = win_side not in ("1", "2")
        side_a_won = win_side != "2"  # default to side A on an uncertain flag

        if side_a_won:
            win_id, win_first, win_last, win_school, win_school_abbrev = 14, 16, 17, 18, 19
            win_class_year, win_team_id = 52, 53
            lose_id, lose_first, lose_last, lose_school, lose_school_abbrev = 15, 20, 21, 22, 23
            lose_class_year, lose_team_id = 56, 57
        else:
            win_id, win_first, win_last, win_school, win_school_abbrev = 15, 20, 21, 22, 23
            win_class_year, win_team_id = 56, 57
            lose_id, lose_first, lose_last, lose_school, lose_school_abbrev = 14, 16, 17, 18, 19
            lose_class_year, lose_team_id = 52, 53

        score, time_seconds = _decode_score_and_time(row, side_a_won)

        out.append(
            WrestlerMatch(
                match_id=_s(row, 0) or "",
                weight=_s(row, 1),
                victory_type_code=vtype_code,
                victory_type=_s(row, 3),
                victory_type_abbrev=_s(row, 4),
                is_bye=is_bye,
                winner_id=_s(row, win_id),
                winner_name=f"{_s(row, win_first) or ''} {_s(row, win_last) or ''}".strip() or None,
                winner_school=_s(row, win_school),
                winner_school_abbrev=_s(row, win_school_abbrev),
                winner_class_year=_s(row, win_class_year),
                winner_team_id=_s(row, win_team_id),
                loser_id=_s(row, lose_id),
                loser_name=f"{_s(row, lose_first) or ''} {_s(row, lose_last) or ''}".strip() or None,
                loser_school=_s(row, lose_school),
                loser_school_abbrev=_s(row, lose_school_abbrev),
                loser_class_year=_s(row, lose_class_year),
                loser_team_id=_s(row, lose_team_id),
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
                win_side_uncertain=win_side_uncertain,
                score=score,
                time_seconds=time_seconds,
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
        "source_score": m.score,
        "source_time_seconds": m.time_seconds,
        "date_start": m.date_start,
        "date_end": m.date_end,
        "extraction_confidence": 0.5 if m.win_side_uncertain else 1.0,
    }

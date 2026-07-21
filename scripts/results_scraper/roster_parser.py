"""twroster.py — parser for a team's wrestler roster, as embedded inline in
WrestlerMatches.jsp / TeamRoster.jsp's page HTML.

Discovered 2026-07-20 alongside twwrestlermatches.py: unlike match data
(which loads via a separate AJAX call), the roster - every wrestler on a
team, with their wrestler id - is rendered server-side, inline in the page's
own <script> block, as:

    jsonStr = "[[\"<wrestlerId>\",\"<shortId>\",\"<first>\",\"<last>\", ...]]";
    if(jsonStr!="") wrestlers = eval("(" + replaceJSPForJSON(jsonStr) + ")");

This means the ENTIRE crawl only needs two request types per team:
  1. One page fetch (WrestlerMatches.jsp?teamId=<id>) -> every wrestler id
     on the roster, via this module.
  2. One AjaxFunctions.jsp call per wrestler id (twwrestlermatches.py) for
     their whole season.
No manual wrestler-id lookup needed anywhere in the pipeline.

Row field index map (0-based), confirmed against a real 33-wrestler
Arizona State roster capture:
  0  wrestler id (long form - the id used everywhere else, e.g. as
     wrestlerIds= in getWrestlerMatches)
  1  wrestler short id (legacy numeric id, appears duplicated in match rows)
  2  first name (display/nickname, e.g. "Kyler")
  3  last name
  4  team id
  5  team name (full)
  6  team abbrev
  7  unclear (small int, e.g. "6" - possibly a division/conference code)
  8  weight class id (this team's internal id for the wrestler's current
     lineup slot - distinct from the numeric weight itself)
  9  weight (current lineup weight class, e.g. "133")
  10 age
  11 class year ("Fr.", "So.", "Jr.", "Sr.", "RS Fr.", "RS Sr.", "n/a", ...)
  12-16 unclear/unused (null in every sampled row)
  17 wins (season win count at capture time)
  18 losses
  19 win percentage (decimal string)
  20 gender code ("M")
  21 active flag ("Y"/"N")
  22 unclear (null in every sampled row)
  23 another id (unclear purpose)
  24 state
  25-26 flags (unclear)
  27 weigh-in weight (precise, e.g. "131.01" vs the nominal "133")
  28 weight (duplicate of 9)
  29 email
  30 weight class id (duplicate of 8)
  31 weigh-in weight (duplicate of 27)
  32 weight (duplicate of 9/28)
  33 flag
  34 weight class id (duplicate of 8/30)
  35 unclear
  36 weight, decimal form (e.g. "133.0")
  37 short id (duplicate of 1)
  38 legal first name (may differ from display name at index 2, e.g.
     "Eric" vs display "Kyler")
  39 legal last name
  40 birthdate (YYYYMMDD)
  41 high school (often null)
  42 another weight figure (unclear purpose - possibly recent/max weight)
  43 unclear (often null)
  44 mugshot URL, when present
  45 class description ("Col. Freshman", "Redshirt Sr.", ...)
  46 conference/region name (e.g. "Arizona")
  47 flag ("N")
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Optional

_JSON_STR_RE = re.compile(r'jsonStr\s*=\s*"(.*?)";', re.DOTALL)


@dataclass
class RosterWrestler:
    wrestler_id: str
    short_id: Optional[str]
    first_name: Optional[str]
    last_name: Optional[str]
    team_id: Optional[str]
    team_name: Optional[str]
    team_abbrev: Optional[str]
    weight: Optional[str]
    age: Optional[str]
    class_year: Optional[str]
    wins: Optional[str]
    losses: Optional[str]
    win_pct: Optional[str]
    state: Optional[str]
    legal_first_name: Optional[str]
    legal_last_name: Optional[str]
    birthdate: Optional[str]
    class_description: Optional[str]
    raw_row: list


def _s(row: list, idx: int) -> Optional[str]:
    if idx >= len(row):
        return None
    v = row[idx]
    return None if v is None else str(v)


def extract_roster_json(html: str) -> Optional[list]:
    """Pull the raw wrestler array out of a WrestlerMatches.jsp/TeamRoster.jsp
    page's HTML. Returns None if no roster script block is found (e.g. wrong
    page, or an empty/inaccessible team)."""
    m = _JSON_STR_RE.search(html)
    if not m:
        return None
    raw = m.group(1)
    if raw == "":
        return []
    # The JSP emits this as a JS string literal (backslash-escaped quotes);
    # unescape before parsing as JSON.
    unescaped = raw.replace('\\"', '"').replace("\\\\", "\\")
    return json.loads(unescaped)


def parse_roster(rows: list) -> list[RosterWrestler]:
    out = []
    for row in rows:
        out.append(
            RosterWrestler(
                wrestler_id=_s(row, 0) or "",
                short_id=_s(row, 1),
                first_name=_s(row, 2),
                last_name=_s(row, 3),
                team_id=_s(row, 4),
                team_name=_s(row, 5),
                team_abbrev=_s(row, 6),
                weight=_s(row, 9),
                age=_s(row, 10),
                class_year=_s(row, 11),
                wins=_s(row, 17),
                losses=_s(row, 18),
                win_pct=_s(row, 19),
                state=_s(row, 24),
                legal_first_name=_s(row, 38),
                legal_last_name=_s(row, 39),
                birthdate=_s(row, 40),
                class_description=_s(row, 45),
                raw_row=row,
            )
        )
    return out


def parse_roster_page(html: str) -> list[RosterWrestler]:
    """Convenience: extract + parse in one call. Returns [] if the page has
    no roster data (empty team, wrong page, etc.) - not an error."""
    rows = extract_roster_json(html)
    if not rows:
        return []
    return parse_roster(rows)

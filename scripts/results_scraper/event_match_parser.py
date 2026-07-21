"""event_match_parser.py — parse EventMatches.jsp HTML into MatchRecords.

The pages are server-rendered. Two common table shapes are handled:

(a) Summary column:  | Weight | Summary |
    "Spencer Lee (Penn State) 24-0, Jr. over Nick Suriano (Rutgers) 19-2, Sr. (Dec 7-2)"
    "Nick Lee (Penn State) W Jaydin Eierman (Iowa), 5-3 Dec"

(b) Separate columns: | Weight | Winner | Loser | Score | Result | (Round) |

Round context comes from full-width section rows ("Champ. Round 1",
"Quarterfinals", "Cons. Round 2", ...) or a dedicated Round column.

Rules: NEVER invent values. Unparseable fields are None. Every record keeps
its raw row text (raw_fragment) and an extraction_confidence score.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Optional

from bs4 import BeautifulSoup

# --------------------------------------------------------------------------
# Regexes / vocab
# --------------------------------------------------------------------------

ROUND_RE = re.compile(
    r"(champ|consol|cons\.|quarter|semi|final|blood|place|placing|round|rd\b|"
    r"pigtail|1st|2nd|3rd|5th|7th|medal)",
    re.IGNORECASE,
)

SCORE_RE = re.compile(r"\d{1,3}\s*-\s*\d{1,3}")
TIME_RE = re.compile(r"\d{1,2}:\d{2}")

# "X over Y (Dec 7-2)" / "X over Y" (no detail)
OVER_RE = re.compile(
    r"^(?P<w>.+?)\s+over\s+(?P<l>.+?)\s*(?:\((?P<d>[^()]*)\))?\s*$",
    re.IGNORECASE | re.DOTALL,
)
# "X def. Y, 7-2 Dec" / "X defeated Y (MD 10-2)"
DEF_RE = re.compile(
    r"^(?P<w>.+?)\s+def\.?(?:eated)?\s+(?P<l>.+?)\s*"
    r"(?:[,(]\s*(?P<d>[^()]*)\)?)?\s*$",
    re.IGNORECASE | re.DOTALL,
)
# "X (School) W Y (School), 5-3 Dec"  and  "X (School) L Y (School), 2-10 Major"
WL_RE = re.compile(
    r"^(?P<a>.+?)\s+(?P<wl>[WL])\s+(?P<b>.+?)\s*"
    r"(?:,\s*(?P<score>\d{1,3}\s*-\s*\d{1,3}|\d{1,2}:\d{2}))?\s*"
    r"(?P<rtype>[A-Za-z. ]*)?\s*$",
    re.DOTALL,
)

NAME_SCHOOL_RE = re.compile(r"^(?P<name>.*?)\s*\((?P<school>[^()]*)\)\s*(?P<rest>.*)$", re.DOTALL)
TRAILING_RECORD_RE = re.compile(r"\s+\d{1,3}-\d{1,3}(?:-\d{1,3})?\b.*$", re.DOTALL)
TRAILING_CLASS_RE = re.compile(
    r"\s+(R?Fr|R?So|R?Jr|R?Sr|Gr|5th|6th)\.?$", re.IGNORECASE
)

WEIGHT_HEADER_KEYS = ("weight", "wt")
RESULT_HEADER_KEYS = ("result", "summary", "outcome", "match", "type", "victory", "decision", "how")
ROUND_HEADER_KEYS = ("round", "rd")

RESULT_LIKE_RE = re.compile(
    r"(\bover\b|\bdef\.?|\b[WL]\b|\d{1,3}\s*-\s*\d{1,3}|"
    r"\b(dec|md|maj|tf|tech|fall|pin|inj|dq|fft|mff)\b)",
    re.IGNORECASE,
)

VICTORY_RULES = [
    (re.compile(r"\b(mff|med\.?|medical)\b", re.I), "medical_forfeit"),
    (re.compile(r"\b(inj\.?|injury)\b", re.I), "injury_default"),
    (re.compile(r"\b(dq|disq\.?|disqualification)\b", re.I), "disqualification"),
    (re.compile(r"\b(fft|ff|for\.?|forfeit)\b", re.I), "forfeit"),
    (re.compile(r"\b(fall|pin|f)\b", re.I), "fall"),
    (re.compile(r"\b(tf|tech\.?|technical)\b", re.I), "tech_fall"),
    (re.compile(r"\b(md|maj\.?|major)\b", re.I), "major"),
    (re.compile(r"\b(dec|sv|tb|ot)\b", re.I), "decision"),
]

PLATFORM_VICTORY_TYPES = {
    "decision", "major", "tech_fall", "fall",
    "medical_forfeit", "injury_default", "disqualification", "forfeit",
}


# --------------------------------------------------------------------------
# Record
# --------------------------------------------------------------------------

@dataclass
class MatchRecord:
    weight_text: Optional[str] = None
    winner: Optional[str] = None
    winner_school: Optional[str] = None
    loser: Optional[str] = None
    loser_school: Optional[str] = None
    score: Optional[str] = None
    victory_type: Optional[str] = None
    round_text: Optional[str] = None
    raw_fragment: str = ""
    extraction_confidence: float = 0.4
    team_id: Optional[str] = None
    team_name: Optional[str] = None


# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------

def _text(el) -> str:
    return re.sub(r"\s+", " ", el.get_text(" ", strip=True))


def _cells(row):
    return row.find_all(["td", "th"], recursive=False)


def normalize_victory_type(text: Optional[str]) -> Optional[str]:
    if not text:
        return None
    for pattern, vtype in VICTORY_RULES:
        if pattern.search(text):
            return vtype
    return None


def _extract_score(text: Optional[str]) -> Optional[str]:
    if not text:
        return None
    m = SCORE_RE.search(text)
    if m:
        return m.group(0)
    m = TIME_RE.search(text)
    if m:
        return m.group(0)
    return None


def _clean_wrestler(segment: Optional[str]) -> tuple[Optional[str], Optional[str]]:
    """Split "Name (School) 24-0, Jr." -> ("Name", "School"). Never guesses."""
    if not segment:
        return None, None
    seg = segment.strip().strip(",").strip()
    if not seg:
        return None, None
    school = None
    m = NAME_SCHOOL_RE.match(seg)
    if m:
        name = m.group("name").strip()
        school = m.group("school").strip() or None
    else:
        name = seg
    name = TRAILING_RECORD_RE.sub("", name)
    name = TRAILING_CLASS_RE.sub("", name).strip().strip(",").strip()
    return (name or None), school


def _confidence(winner, loser, score, victory_type) -> float:
    if winner and loser and score and victory_type:
        return 1.0
    if winner:
        return 0.7
    return 0.4


def _has_bold(cell) -> bool:
    return cell.find(["b", "strong"]) is not None


def _pin_icon_victory(row) -> Optional[str]:
    for img in row.find_all("img"):
        alt = (img.get("alt") or "") + " " + (img.get("title") or "")
        if re.search(r"fall|pin", alt, re.IGNORECASE):
            return "fall"
    return None


# --------------------------------------------------------------------------
# Summary-string parsing (shape a)
# --------------------------------------------------------------------------

def parse_summary(text: str, row=None) -> dict:
    """Parse one free-text result cell. Returns a partial-record dict; fields
    that cannot be parsed are None (never guessed)."""
    out = {
        "winner": None, "winner_school": None,
        "loser": None, "loser_school": None,
        "score": None, "victory_type": None,
    }
    flat = re.sub(r"\s+", " ", text or "").strip()
    if not flat:
        return out

    m = OVER_RE.match(flat)
    if m:
        out["winner"], out["winner_school"] = _clean_wrestler(m.group("w"))
        out["loser"], out["loser_school"] = _clean_wrestler(m.group("l"))
        detail = m.group("d")
        out["score"] = _extract_score(detail)
        out["victory_type"] = normalize_victory_type(detail)
    else:
        m = WL_RE.match(flat)
        if m:
            a, wl, b = m.group("a"), m.group("wl").upper(), m.group("b")
            w_seg, l_seg = (a, b) if wl == "W" else (b, a)
            out["winner"], out["winner_school"] = _clean_wrestler(w_seg)
            out["loser"], out["loser_school"] = _clean_wrestler(l_seg)
            out["score"] = m.group("score")
            out["victory_type"] = normalize_victory_type(m.group("rtype"))
        else:
            m = DEF_RE.match(flat)
            if m:
                out["winner"], out["winner_school"] = _clean_wrestler(m.group("w"))
                out["loser"], out["loser_school"] = _clean_wrestler(m.group("l"))
                detail = m.group("d")
                out["score"] = _extract_score(detail)
                out["victory_type"] = normalize_victory_type(detail)

    if out["victory_type"] is None and row is not None:
        out["victory_type"] = _pin_icon_victory(row)
    return out


# --------------------------------------------------------------------------
# Table detection
# --------------------------------------------------------------------------

def _map_header(cells) -> dict:
    """Map header cells to semantic roles. Returns {} if not a match table."""
    roles: dict[str, int] = {}
    for i, cell in enumerate(cells):
        t = _text(cell).casefold()
        if not t:
            continue
        if any(k in t for k in WEIGHT_HEADER_KEYS):
            roles.setdefault("weight", i)
        elif t == "winner":
            roles.setdefault("winner", i)
        elif t == "loser":
            roles.setdefault("loser", i)
        elif "opponent" in t:
            roles.setdefault("opponent", i)
        elif t.startswith("wrestler") or t == "name":
            roles.setdefault("wrestler2" if "wrestler1" in roles else "wrestler1", i)
        elif t == "score":
            roles.setdefault("score", i)
        elif any(k == t for k in ROUND_HEADER_KEYS) or "round" in t:
            roles.setdefault("round", i)
        elif any(k in t for k in RESULT_HEADER_KEYS):
            roles.setdefault("result", i)
    return roles


def _classify_shape(roles: dict) -> Optional[str]:
    if "weight" not in roles:
        return None
    if "winner" in roles or ("wrestler1" in roles and "opponent" in roles):
        return "columns"
    if "result" in roles:
        return "summary"
    return None


def _find_match_tables(soup) -> list[tuple]:
    """Return list of (table, header_row_index, roles, shape)."""
    found = []
    for table in soup.find_all("table"):
        if table.find("table"):  # skip wrapper tables to avoid double-parsing
            continue
        rows = table.find_all("tr")
        if not rows:
            continue
        for h_idx, row in enumerate(rows[:3]):
            cells = _cells(row)
            if not cells:
                continue
            roles = _map_header(cells)
            shape = _classify_shape(roles)
            if shape:
                found.append((table, h_idx, roles, shape))
                break
    if found:
        return found

    # Fallback: largest table with > 5 rows containing result-like text.
    best = None
    for table in soup.find_all("table"):
        if table.find("table"):
            continue
        rows = table.find_all("tr")
        if len(rows) <= 5:
            continue
        body = _text(table)
        if not RESULT_LIKE_RE.search(body):
            continue
        if best is None or len(rows) > len(best[0].find_all("tr")):
            best = (table, -1, {"weight": 0, "result": 1}, "summary")
    return [best] if best else []


# --------------------------------------------------------------------------
# Row parsing
# --------------------------------------------------------------------------

def _is_section_row(row, cells) -> Optional[str]:
    """Full-width round banner rows -> round label; else None."""
    if len(cells) == 1 or any(int(c.get("colspan", 1)) >= 2 for c in cells):
        text = _text(row)
        if text and len(text) < 80 and ROUND_RE.search(text):
            return text
    return None


def _looks_weighty(text: str) -> bool:
    return bool(re.search(r"\d", text)) or bool(re.search(r"hwt|heavy", text, re.I))


def _parse_summary_row(row, cells, roles, carried_weight, current_round, team_id, team_name):
    w_idx = roles.get("weight", 0)
    r_idx = roles.get("result", 1)
    weight = carried_weight
    if len(cells) > r_idx:
        wt = _text(cells[w_idx]) if w_idx < len(cells) else ""
        if wt:
            carried_weight = wt
            weight = wt
        result_text = " ".join(_text(c) for c in cells[r_idx:]).strip()
        result_cell = cells[r_idx]
    else:
        # Row short by one cell: weight cell was a rowspan above us.
        only = _text(cells[0])
        if _looks_weighty(only) and not RESULT_LIKE_RE.search(only):
            # Weight-only filler row (e.g. rowspan artifact): carry it, skip.
            return None, only
        result_text = only
        result_cell = cells[0]

    if not result_text:
        return None, carried_weight
    if not weight:
        # No weight context at all: cannot place this row; skip safely.
        return None, carried_weight

    parsed = parse_summary(result_text, row=row)
    # Bold winner markup as a tiebreak when regex parsing found nothing.
    if parsed["winner"] is None and _has_bold(result_cell):
        bold = _text(result_cell.find(["b", "strong"]))
        name, school = _clean_wrestler(bold)
        parsed["winner"], parsed["winner_school"] = name, school or parsed["winner_school"]

    rec = MatchRecord(
        weight_text=weight,
        winner=parsed["winner"],
        winner_school=parsed["winner_school"],
        loser=parsed["loser"],
        loser_school=parsed["loser_school"],
        score=parsed["score"],
        victory_type=parsed["victory_type"],
        round_text=current_round,
        raw_fragment=_text(row)[:400],
        extraction_confidence=_confidence(
            parsed["winner"], parsed["loser"], parsed["score"], parsed["victory_type"]
        ),
        team_id=team_id,
        team_name=team_name,
    )
    return rec, carried_weight


def _parse_columns_row(row, cells, roles, carried_weight, current_round, team_id, team_name):
    def cell_text(role):
        idx = roles.get(role)
        return _text(cells[idx]) if idx is not None and idx < len(cells) else ""

    def cell(role):
        idx = roles.get(role)
        return cells[idx] if idx is not None and idx < len(cells) else None

    weight = cell_text("weight") or carried_weight
    if cell_text("weight"):
        carried_weight = cell_text("weight")

    row_round = cell_text("round") or current_round
    result_text = cell_text("result")
    score_text = cell_text("score")

    winner_seg = cell_text("winner")
    loser_seg = cell_text("loser")
    w1_seg = cell_text("wrestler1")
    opp_seg = cell_text("opponent")

    winner = loser = None
    if winner_seg or loser_seg:
        winner, w_school = _clean_wrestler(winner_seg)
        loser, l_school = _clean_wrestler(loser_seg)
    else:
        w_school = l_school = None
        # W/L indicator in the result column ("W Dec 7-2" / "L 5-3").
        wl = re.match(r"^\s*([WL])\b", result_text or "")
        bold_w1 = _has_bold(cell("wrestler1")) if cell("wrestler1") is not None else False
        bold_opp = _has_bold(cell("opponent")) if cell("opponent") is not None else False
        if wl:
            first_is_winner = wl.group(1) == "W"
        elif bold_w1 and not bold_opp:
            first_is_winner = True
        elif bold_opp and not bold_w1:
            first_is_winner = False
        else:
            first_is_winner = None
        if first_is_winner is True:
            winner, w_school = _clean_wrestler(w1_seg)
            loser, l_school = _clean_wrestler(opp_seg)
        elif first_is_winner is False:
            winner, w_school = _clean_wrestler(opp_seg)
            loser, l_school = _clean_wrestler(w1_seg)
        else:
            w_school = l_school = None

    score = score_text or _extract_score(result_text)
    victory_type = normalize_victory_type(result_text)
    if victory_type is None:
        victory_type = normalize_victory_type(score_text)
    if victory_type is None:
        victory_type = _pin_icon_victory(row)

    # Skip fully empty filler rows; keep partial rows at low confidence.
    if not any([winner, loser, w1_seg, opp_seg, result_text, score_text]):
        return None, carried_weight

    rec = MatchRecord(
        weight_text=weight or None,
        winner=winner,
        winner_school=w_school,
        loser=loser,
        loser_school=l_school,
        score=score or None,
        victory_type=victory_type,
        round_text=row_round,
        raw_fragment=_text(row)[:400],
        extraction_confidence=_confidence(winner, loser, score, victory_type),
        team_id=team_id,
        team_name=team_name,
    )
    return rec, carried_weight


# --------------------------------------------------------------------------
# Public entry point
# --------------------------------------------------------------------------

def parse_event_matches(
    html: str,
    team_id: Optional[str] = None,
    team_name: Optional[str] = None,
) -> list[MatchRecord]:
    """Parse an EventMatches.jsp page into MatchRecords. Never raises on
    malformed rows — they are captured at confidence 0.4 or skipped."""
    soup = BeautifulSoup(html or "", "lxml")
    records: list[MatchRecord] = []

    for table, header_idx, roles, shape in _find_match_tables(soup):
        rows = table.find_all("tr")
        carried_weight: Optional[str] = None
        current_round: Optional[str] = None
        for row in rows[header_idx + 1:]:
            try:
                cells = _cells(row)
                if not cells:
                    continue
                section = _is_section_row(row, cells)
                if section is not None:
                    current_round = section
                    continue
                if shape == "summary":
                    rec, carried_weight = _parse_summary_row(
                        row, cells, roles, carried_weight, current_round, team_id, team_name
                    )
                else:
                    rec, carried_weight = _parse_columns_row(
                        row, cells, roles, carried_weight, current_round, team_id, team_name
                    )
                if rec is not None:
                    records.append(rec)
            except Exception:
                # Defensive: a malformed row must never kill the page parse.
                try:
                    frag = _text(row)[:400]
                except Exception:
                    frag = ""
                if frag:
                    records.append(
                        MatchRecord(
                            weight_text=carried_weight,
                            round_text=current_round,
                            raw_fragment=frag,
                            extraction_confidence=0.4,
                            team_id=team_id,
                            team_name=team_name,
                        )
                    )
    return records

"""twnormalize.py — MatchRecord -> platform external_result_candidate dicts.

Handles:
- weight normalization ("125 lbs" -> "125", "HWT"/"Heavyweight" -> "285")
- cross-team-page dedupe (each bout appears on both opponents' team pages)
- external_match_key generation (stable, order-independent on winner/loser)
- conflict detection when two pages disagree about who won
"""

from __future__ import annotations

import hashlib
import re
from typing import Optional

from twparse import MatchRecord

_HEAVY_RE = re.compile(r"hwt|heavy", re.IGNORECASE)
_WS_RE = re.compile(r"\s+")
_PUNCT_RE = re.compile(r"[^a-z0-9 ]+")


def normalize_weight(weight_text: Optional[str]) -> Optional[str]:
    """'125 lbs' -> '125'; 'HWT'/'Heavyweight' -> '285'; garbage -> None."""
    if not weight_text:
        return None
    if _HEAVY_RE.search(weight_text):
        return "285"
    digits = re.sub(r"\D", "", weight_text)
    return digits or None


def normalize_name(name: Optional[str]) -> str:
    if not name:
        return ""
    n = name.casefold()
    n = _PUNCT_RE.sub("", n)
    return _WS_RE.sub(" ", n).strip()


def normalize_round(round_text: Optional[str]) -> str:
    if not round_text:
        return ""
    return _WS_RE.sub(" ", round_text.strip().casefold())


def external_match_key(event_id: str, rec: MatchRecord) -> str:
    """Stable bout key, independent of which team's page listed the match
    (winner/loser name order is sorted before hashing)."""
    weight_norm = normalize_weight(rec.weight_text) or ""
    pair = sorted([normalize_name(rec.winner), normalize_name(rec.loser)])
    round_norm = normalize_round(rec.round_text)
    raw = f"{event_id}|{weight_norm}|{pair}|{round_norm}"
    return hashlib.sha1(raw.encode()).hexdigest()[:16]


def to_candidate(rec: MatchRecord, event_id: str, occurred_at: Optional[str]) -> dict:
    return {
        "external_match_key": external_match_key(event_id, rec),
        "source_weight_class": normalize_weight(rec.weight_text),
        "source_round": rec.round_text,
        "source_winner": rec.winner,
        "source_winner_school": rec.winner_school,
        "source_loser": rec.loser,
        "source_loser_school": rec.loser_school,
        "source_score": rec.score,
        "source_victory_type": rec.victory_type,
        "raw_fragment": rec.raw_fragment,
        "extraction_confidence": rec.extraction_confidence,
        "occurred_at": occurred_at,
    }


def dedupe(
    records: list[MatchRecord],
    event_id: str,
    occurred_at: Optional[str] = None,
) -> tuple[list[dict], dict]:
    """Collapse duplicates across team pages.

    A match appears on both opponents' pages. When the same key appears more
    than once (different listing order is normal and expected) the highest
    confidence record wins. When the duplicates DISAGREE about the winner,
    the kept record is additionally reported with conflict_hint=True in the
    side report (never silently merged away).

    Returns (candidates, report).
    """
    groups: dict[str, list[MatchRecord]] = {}
    for rec in records:
        groups.setdefault(external_match_key(event_id, rec), []).append(rec)

    candidates: list[dict] = []
    conflicts: list[dict] = []
    duplicates_merged = 0

    for key, group in groups.items():
        group.sort(key=lambda r: r.extraction_confidence, reverse=True)
        kept = group[0]
        candidates.append(to_candidate(kept, event_id, occurred_at))
        if len(group) > 1:
            duplicates_merged += len(group) - 1
            # Genuine conflict = duplicates disagree about who won. A simple
            # swap of listing order with the SAME winner is normal duplication
            # (each bout shows on both opponents' pages) and is not flagged.
            winner_identities = {normalize_name(r.winner) for r in group if r.winner}
            if len(winner_identities) > 1:
                conflicts.append(
                    {
                        "external_match_key": key,
                        "conflict_hint": True,
                        "kept_winner": kept.winner,
                        "kept_confidence": kept.extraction_confidence,
                        "winners_seen": sorted({r.winner for r in group if r.winner}),
                        "dropped": [
                            {
                                "winner": r.winner,
                                "loser": r.loser,
                                "team_id": r.team_id,
                                "raw_fragment": r.raw_fragment[:200],
                            }
                            for r in group[1:]
                        ],
                    }
                )

    report = {
        "total_rows": len(records),
        "unique_matches": len(candidates),
        "duplicates_merged": duplicates_merged,
        "conflicts": conflicts,
    }
    return candidates, report

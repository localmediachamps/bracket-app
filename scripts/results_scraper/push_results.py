"""twpush.py — push normalized result candidates to the TAKEDOWN platform.

Endpoint contract (see task spec / ARCHITECTURE.md ingestion summary):

    POST {api_base}/admin/sources/{source_config_id}/ingest
    Authorization: Bearer <token>
    Body: {"candidates": [ {external_match_key, source_weight_class, ...}, ...]}

    Response (per batch): {"received": n, "created": n, "duplicates": n,
                           "auto_approved": n, "needs_review": n, "conflicts": n}
"""

from __future__ import annotations

import time

import requests

SUMMARY_KEYS = ("received", "created", "duplicates", "auto_approved", "needs_review", "conflicts")

BACKOFF_SECONDS = 10


class PushError(RuntimeError):
    pass


def _post_with_backoff(session: requests.Session, url: str, payload: dict) -> requests.Response:
    resp = session.post(url, json=payload, timeout=60)
    if resp.status_code == 429 or resp.status_code >= 500:
        time.sleep(BACKOFF_SECONDS)
        resp = session.post(url, json=payload, timeout=60)
    if resp.status_code >= 400:
        body = resp.text[:300]
        raise PushError(f"ingest POST failed: HTTP {resp.status_code} — {body}")
    return resp


def push(
    api_base: str,
    token: str,
    source_config_id,
    candidates: list[dict],
    batch: int = 100,
    verbose: bool = False,
) -> dict:
    """POST candidates in batches; returns accumulated server summary."""
    if not api_base:
        raise PushError("api_base is required (--api-base or TW_API_BASE)")
    if not token:
        raise PushError("token is required (--token or TW_API_TOKEN)")

    url = f"{api_base.rstrip('/')}/admin/sources/{source_config_id}/ingest"
    session = requests.Session()
    session.headers.update(
        {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    )

    totals = {k: 0 for k in SUMMARY_KEYS}
    batches = [candidates[i : i + batch] for i in range(0, len(candidates), batch)]
    if not batches:
        print("push: 0 candidates — nothing to send")
        return totals

    for i, chunk in enumerate(batches, 1):
        resp = _post_with_backoff(session, url, {"candidates": chunk})
        try:
            summary = resp.json()
        except ValueError:
            summary = {}
        line = f"batch {i}/{len(batches)} ({len(chunk)} candidates): HTTP {resp.status_code}"
        for k in SUMMARY_KEYS:
            v = summary.get(k)
            if isinstance(v, (int, float)):
                totals[k] += v
                line += f" {k}={v}"
        print(line, flush=True)

    print("push totals: " + " ".join(f"{k}={totals[k]}" for k in SUMMARY_KEYS), flush=True)
    return totals

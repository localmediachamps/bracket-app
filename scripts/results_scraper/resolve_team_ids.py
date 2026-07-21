"""resolve_team_ids.py — team ids are NOT stable across seasons on the
external results provider (confirmed: Air Force was 758758150 in 2025-26,
1434509147 in 2024-25). This script re-derives a fresh team_id for every team
name in an existing team-id CSV, for a DIFFERENT season, by driving the real
Teams search UI (genuine clicks - team ids can't be looked up any other way).

Run:  python scripts/results_scraper/resolve_team_ids.py \
        --season-id 841725138 --gb-id 3 \
        --in results_scraper_bundle/ncaa_d1_team_ids_2025_26.csv \
        --out results_scraper_bundle/ncaa_d1_team_ids_2024_25.csv

See trackwrestling-session-bootstrap-solved memory note: must run headed
(not headless), and season/governing-body binding needs the real
seasonSelected()/Login() JS flow, not a plain URL.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import time
from pathlib import Path

DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)


def bootstrap_season(page, season_id: str, gb_label_substr: str = "NCAA"):
    page.goto("https://www.trackwrestling.com/seasons/index.jsp", wait_until="domcontentloaded")
    page.wait_for_timeout(1500)
    page.evaluate(f"seasonSelected({season_id})")
    page.wait_for_timeout(1500)
    combo = page.get_by_role("combobox", name="governing body")
    combo.select_option(label=next(
        o for o in combo.locator("option").all_inner_texts() if gb_label_substr in o
    ))
    page.get_by_role("button", name="Login").click()
    page.wait_for_timeout(2000)


def search_team(page, team_name: str) -> list[tuple[str, str, str]]:
    """Returns list of (label_text, state, team_id) matches from the Teams search."""
    page.get_by_role("link", name="Teams", exact=True).click()
    page.wait_for_timeout(1000)
    frame = page.locator('iframe[name="PageFrame"]').content_frame
    frame.get_by_role("button", name="Search").first.click()
    page.wait_for_timeout(800)
    frame.get_by_role("textbox", name="team name").fill(team_name)
    frame.locator("#searchFrame").get_by_role("button", name="Search").click()
    page.wait_for_timeout(1500)

    results = []
    for link in frame.get_by_role("link").all():
        href = link.get_attribute("href") or ""
        m = re.search(r"teamId=(\d+)", href)
        if not m:
            continue
        text = (link.inner_text() or "").strip()
        if ", " in text:
            name, state = text.rsplit(", ", 1)
        else:
            name, state = text, ""
        results.append((name, state, m.group(1)))
    return results


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--season-id", required=True)
    ap.add_argument("--gb-id", required=True)
    ap.add_argument("--in", dest="in_path", required=True)
    ap.add_argument("--out", dest="out_path", required=True)
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args()

    from playwright.sync_api import sync_playwright

    with open(args.in_path, encoding="utf-8") as f:
        teams = list(csv.DictReader(f))
    if args.limit:
        teams = teams[: args.limit]

    resolved = []
    unresolved = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        ctx = browser.new_context(user_agent=DEFAULT_USER_AGENT)
        ctx.add_init_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined});")
        page = ctx.new_page()

        bootstrap_season(page, args.season_id)

        for i, team in enumerate(teams, 1):
            name = team["team_name"]
            old_state = team.get("state", "")
            print(f"[{i}/{len(teams)}] {name} ...", flush=True)
            try:
                matches = search_team(page, name)
            except Exception as exc:
                print(f"  ERROR: {exc}")
                unresolved.append({"team_name": name, "old_state": old_state, "reason": str(exc)})
                continue

            exact = [m for m in matches if m[0].strip().casefold() == name.strip().casefold()]
            if len(exact) == 1:
                _, state, team_id = exact[0]
                resolved.append({"team_name": name, "state": state, "team_id": team_id})
                print(f"  -> team_id={team_id} ({state})")
            elif len(exact) > 1 and old_state:
                state_match = [m for m in exact if m[1].strip().casefold() == old_state.strip().casefold()]
                if len(state_match) == 1:
                    _, state, team_id = state_match[0]
                    resolved.append({"team_name": name, "state": state, "team_id": team_id})
                    print(f"  -> team_id={team_id} ({state}) [disambiguated by state]")
                else:
                    print(f"  AMBIGUOUS: {exact}")
                    unresolved.append({"team_name": name, "old_state": old_state, "reason": f"ambiguous: {exact}"})
            else:
                print(f"  NOT FOUND (candidates: {matches})")
                unresolved.append({"team_name": name, "old_state": old_state, "reason": f"no exact match, candidates={matches}"})

            time.sleep(1.2)

        browser.close()

    out_path = Path(args.out_path)
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["team_name", "state", "team_id"])
        writer.writeheader()
        writer.writerows(resolved)

    print(f"\nresolved {len(resolved)}/{len(teams)} teams -> {out_path}")
    if unresolved:
        print(f"{len(unresolved)} unresolved:")
        for u in unresolved:
            print(f"  - {u['team_name']}: {u['reason']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

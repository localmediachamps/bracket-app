# Trackwrestling NCAA Division I team IDs and scraping notes

## Files

- [Team ID CSV](trackwrestling_2026_ncaa_d1_team_ids.csv) — 74 unique team IDs extracted from the team links on the **2026 NCAA Division I Championships** page.

Upload this Markdown file and the CSV to the same Colab working directory so the relative link and examples remain valid.

## Dataset scope

The CSV was generated from the NCAA tournament team-results links supplied in the source HTML. It contains one row per listed team with these fields:

- `team_name`
- `state`
- `team_id`
- `season_id`
- `event_id`
- `tournament_id`
- `source_tournament`
- `event_matches_url_without_session`

The source page yielded **74 unique teams**, **74 unique team IDs**, and one event ID: `8710102132`.

### Important limitation

This is a high-coverage list, not necessarily a complete list of every Division I wrestling program. The source is the NCAA championship page, so a program with no NCAA qualifier may be absent. Team IDs also appear to be season-specific; rebuild or verify the map for a different Trackwrestling season.

## What the request comparison established

Two captured `EventMatches.jsp` requests used the same `seasonId` and `teamId` with different `eventId` values. That is strong evidence that the `teamId` is a **season-team identifier** that can be reused across events within that season.

Observed request shape:

```text
https://www.trackwrestling.com/seasons/EventMatches.jsp
    ?TIM=<current Unix time in milliseconds>
    &twSessionId=<current Trackwrestling session token>
    &seasonId=1560238138
    &eventId=<event ID>
    &teamId=<season team ID>
```

The captured navigation also showed that changing the team dropdown generated another normal GET request. The hidden `MethodCaller.jsp` iframe appears to be generic page infrastructure rather than a required team-selection POST for this page.

## Parameter interpretation

| Parameter | Likely role | Handling recommendation |
|---|---|---|
| `seasonId` | Identifies the Trackwrestling season | Keep fixed while working within one season |
| `eventId` | Identifies a tournament or event record | Discover from event links; do not brute-force |
| `teamId` | Identifies the season team | Load from the included CSV |
| `twSessionId` | Application session token | Obtain from a fresh browsing session; do not hard-code permanently |
| `TIM` | Millisecond timestamp/cache buster | Generate with `int(time.time() * 1000)` |
| `USER_SESSIONID` cookie | Server session cookie | Let `requests.Session()` retain it after an entry-page request |

## Load the CSV in Colab

```python
import pandas as pd

TEAM_ID_CSV = "/content/trackwrestling_2026_ncaa_d1_team_ids.csv"
teams = pd.read_csv(TEAM_ID_CSV, dtype=str)

print(f"Loaded {len(teams)} teams")
display(teams.head())
```

Look up a team:

```python
cornell = teams.loc[
    teams["team_name"].str.casefold() == "cornell",
    "team_id",
].iloc[0]

print(cornell)  # 758803150
```

Create a dictionary:

```python
team_id_by_name = dict(zip(teams["team_name"], teams["team_id"]))
print(team_id_by_name["Penn State"])
```

## Fetch one team/event page

Start by opening a legitimate Trackwrestling season or event entry page so the session receives current cookies. Do not paste old browser-cookie headers into the notebook.

```python
from __future__ import annotations

import time
import requests

BASE_URL = "https://www.trackwrestling.com/seasons/EventMatches.jsp"

session = requests.Session()
session.headers.update({
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0 Safari/537.36"
    )
})


def fetch_event_matches(
    *,
    season_id: str,
    event_id: str,
    team_id: str,
    tw_session_id: str,
) -> str:
    params = {
        "TIM": str(int(time.time() * 1000)),
        "twSessionId": tw_session_id,
        "seasonId": season_id,
        "eventId": event_id,
        "teamId": team_id,
    }

    response = session.get(BASE_URL, params=params, timeout=30)
    response.raise_for_status()

    # Catch common cases where the session expired or the site redirected.
    if "EventMatches.jsp" not in response.url:
        raise RuntimeError(f"Unexpected redirect: {response.url}")
    if len(response.text) < 1_000:
        raise RuntimeError("Response is unexpectedly small; session may be invalid")

    return response.text
```

Example call:

```python
html = fetch_event_matches(
    season_id="1560238138",
    event_id="8710102132",
    team_id=team_id_by_name["Cornell"],
    tw_session_id="REPLACE_WITH_CURRENT_VALUE",
)

print(len(html))
```

## Parse the match table

Because the visible results appear to be server-rendered in the returned HTML, `pandas.read_html` may be enough:

```python
import pandas as pd

candidate_tables = pd.read_html(html)
for index, table in enumerate(candidate_tables):
    print(index, table.shape, list(table.columns))
```

Select the table by expected column names instead of assuming a fixed table number:

```python
match_table = None

for table in candidate_tables:
    normalized = {str(col).strip().casefold() for col in table.columns}
    if {"weight", "summary"}.issubset(normalized):
        match_table = table.copy()
        break

if match_table is None:
    raise RuntimeError("Could not find the match-results table")

display(match_table.head())
```

## Iterate across teams and events

Only request valid event IDs discovered from Trackwrestling pages. Cache responses and use a delay so the script does not repeatedly hit the same page.

```python
from pathlib import Path
import hashlib
import time

CACHE_DIR = Path("/content/trackwrestling_cache")
CACHE_DIR.mkdir(exist_ok=True)


def cached_fetch(*, season_id, event_id, team_id, tw_session_id):
    key = hashlib.sha256(
        f"{season_id}|{event_id}|{team_id}".encode()
    ).hexdigest()
    path = CACHE_DIR / f"{key}.html"

    if path.exists():
        return path.read_text(encoding="utf-8")

    page = fetch_event_matches(
        season_id=season_id,
        event_id=event_id,
        team_id=team_id,
        tw_session_id=tw_session_id,
    )
    path.write_text(page, encoding="utf-8")
    time.sleep(1.5)
    return page
```

## Extract a team-ID map from another team-link page

This lets you regenerate the CSV from HTML whenever the season changes.

```python
from bs4 import BeautifulSoup
from urllib.parse import parse_qs, urlparse
import pandas as pd


def extract_team_ids(page_html: str) -> pd.DataFrame:
    soup = BeautifulSoup(page_html, "html.parser")
    records = []

    for anchor in soup.select('a[href*="EventMatches.jsp"]'):
        href = anchor.get("href", "")
        params = parse_qs(urlparse(href).query)
        team_id = params.get("teamId", [None])[0]
        event_id = params.get("eventId", [None])[0]
        label = anchor.get_text(" ", strip=True)

        if not team_id:
            continue

        team_name, separator, state = label.rpartition(", ")
        if not separator:
            team_name, state = label, ""

        records.append({
            "team_name": team_name,
            "state": state,
            "team_id": team_id,
            "event_id": event_id,
        })

    result = pd.DataFrame(records).drop_duplicates("team_id")
    return result.sort_values("team_name", kind="stable").reset_index(drop=True)
```

## Event-team versus season-team mapping

The event’s Teams page displayed separate `Event Team` and `Season Team` columns. This indicates Trackwrestling maintains an event-local record and maps it to the season team. The tested `EventMatches.jsp` URLs nevertheless reused the same season `teamId` across different events.

Practical rule:

1. Use the CSV’s season `teamId` values.
2. Use only event IDs actually associated with the season.
3. Treat an empty result as potentially meaning “team did not participate,” not necessarily “invalid team ID.”
4. Re-extract the map for a new season rather than assuming IDs are permanent.

## Security and operational notes

- The original copied cURL contained live session cookies and advertising identifiers. They are intentionally excluded from these files.
- Refresh exposed Trackwrestling cookies before continuing.
- Do not commit `USER_SESSIONID`, `twSessionId`, or browser cookie strings to Git or Colab notebooks.
- Respect the site’s terms, access controls, robots guidance, and reasonable request rates.
- Do not attempt to bypass CAPTCHAs or authentication controls.

## Provenance

The team IDs were parsed from the supplied HTML for the **2026 NCAA Division I Championships**, tournament ID `931299132`, event ID `8710102132`. The clean URLs in the CSV omit `TIM`, `twSessionId`, cookies, and advertising identifiers.

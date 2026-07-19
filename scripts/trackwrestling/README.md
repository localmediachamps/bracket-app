# Trackwrestling results scraper (TAKEDOWN)

Stdlib + `requests` + `beautifulsoup4` + `lxml` only. No pandas, no scrapy, no selenium.

Scrapes team-level `EventMatches.jsp` pages from trackwrestling.com, normalizes
bout records, dedupes across team pages (each bout appears on both opponents'
pages), and pushes `external_result_candidate` dicts to the TAKEDOWN platform
ingestion API (`POST {api_base}/admin/sources/{source_config_id}/ingest`).

## Legal & politeness (read first)

- Respect trackwrestling.com's terms of service, robots guidance, and access
  controls. Authorized use only.
- **Never** bypass CAPTCHAs or authentication. If the site asks, stop.
- Request rate is deliberately low: >= 1.0s delay + 0-0.7s random jitter
  between requests; HTTP 429 is honored with a 30s backoff and a single retry.
- Everything is cached on disk (`--cache-dir`, default `.twcache`). Cached
  pages are never re-fetched unless you pass `--refresh`. Cache everything;
  re-parse from cache freely.
- A per-run request budget (`--max-requests`, default 300) stops runaway jobs.
- Never commit `USER_SESSIONID` cookies or `twSessionId` tokens to git.

## Setup

```bash
pip install -r requirements.txt
python selftest.py    # offline self-test; must pass before any real run
```

## Obtaining a session

`EventMatches.jsp` requires a live Trackwrestling session (`twSessionId` +
`USER_SESSIONID` cookie). Two options:

1. **Automatic bootstrap (try first):** the client GETs the season entry page
   (`TWHome.jsp?seasonId=...`, falling back to `Schedule.jsp?...`) and scrapes
   `twSessionId` out of the HTML.
2. **Manual (when bootstrap is blocked):** in a real browser open the season
   page, click any team's matches link, and copy the `twSessionId` query
   parameter from the URL. Then:

   ```bash
   set TW_SESSION_ID=<value>        # Windows
   export TW_SESSION_ID=<value>     # bash
   ```

   or pass `--tw-session-id <value>`.

If the site answers 406 / redirects / returns a stub page, the client
re-bootstraps once, retries once, then raises `SessionExpired` with this
guidance. Sessions expire — refresh and re-run; the cache survives.

## Commands

Run from `scripts/trackwrestling/` (or reference `tw.py` by path).

### Live results: 2026 NCAA Division I Championships

Season `1560238138`, event `8710102132`, team map in
`../../trackwrestling_scraping_bundle/trackwrestling_2026_ncaa_d1_team_ids.csv`.

```bash
# one-shot: fetch -> parse -> push
python tw.py run --season 1560238138 --event 8710102132 ^
    --teams-csv ../../trackwrestling_scraping_bundle/trackwrestling_2026_ncaa_d1_team_ids.csv ^
    --source-config 1 --api-base https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y ^
    --token <admin-token> --occurred-at 2026-03-19 -v

# or poll every 15 minutes during the tournament (forces --refresh per cycle)
python tw.py poll --season 1560238138 --event 8710102132 ^
    --teams-csv ../../trackwrestling_scraping_bundle/trackwrestling_2026_ncaa_d1_team_ids.csv ^
    --source-config 1 --api-base https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y ^
    --token <admin-token> --interval-min 15
```

`--api-base` / `--token` fall back to env `TW_API_BASE` / `TW_API_TOKEN`.

### Fetch and parse separately (inspect before pushing)

```bash
python tw.py fetch --season 1560238138 --event 8710102132 ^
    --teams-csv ../../trackwrestling_scraping_bundle/trackwrestling_2026_ncaa_d1_team_ids.csv -v

python tw.py parse --event 8710102132 --cache-dir .twcache ^
    --occurred-at 2026-03-19 --out candidates_8710102132.json
```

`parse` prints a dedupe report to stderr: pages parsed, total rows, unique
matches, duplicates merged, and any winner conflicts.

### Push later from cache (deliberate re-push / backfill push step)

```bash
python tw.py run --season 1560238138 --event 8710102132 ^
    --teams-csv <csv> --skip-fetch ^
    --source-config 1 --api-base <url> --token <tok>
```

### Full-season backfill (fetch + parse only, NEVER pushes)

```bash
python tw.py backfill ^
    --season-index ../../trackwrestling_scraping_bundle/trackwrestling_2025_26_event_index.csv ^
    --teams-csv ../../trackwrestling_scraping_bundle/trackwrestling_2026_ncaa_d1_team_ids.csv ^
    --cache-dir .twcache --out-dir backfill_out --only-ncaa --limit 5
```

Writes one `backfill_out/<event_id>.json` candidate file per event.
`--only-ncaa` keeps rows whose name contains "NCAA Division I".
Push each event afterwards with a deliberate `run --skip-fetch` (above).

### Regenerate the team-id map for a new season

Save the tournament's team-links page from your browser, then:

```bash
python tw.py teams --html saved_team_links.html --out team_ids_new.csv ^
    --name "2027 NCAA Division I Championships"
```

Team IDs are season-specific — rebuild the map each season.

## Layouts handled by the parser

- **Summary column** (`Weight | Summary`): `"Winner (School) 24-0, Jr. over
  Loser (School) 19-2, Sr. (Dec 7-2)"`, `"X over Y (MD 10-2)"`, `"X over Y
  (Fall 4:22)"`, `"X W Y, 5-3 Dec"`, `"X L Y, 2-10 Major"`, `"X def. Y ..."`.
- **Separate columns** (`Weight | Winner | Loser | Score | Result [| Round]`),
  including `Wrestler | Opponent` variants with a W/L result token or
  bold/strong winner markup.
- Round context from full-width banner rows (`Champ. Round 1`,
  `Quarterfinals`, `Cons. Round 2`, ...) or a Round column.
- Rowspan-style weight cells (weight carried down to subsequent rows).
- Fall pin icons (`<img alt="...fall...">`) as a victory-type fallback.
- Malformed rows never crash the parse: they are captured with
  `extraction_confidence` 0.4 and all unparseable fields left `None`
  (never invented). Confidence: 1.0 = winner+loser+score+type; 0.7 = winner
  known, partial detail; 0.4 = row captured, parse uncertain.

## Dedupe & conflicts

`external_match_key = sha1(event|weight|sorted(winner,loser)|round)[:16]`.
A bout listed on both opponents' pages merges to one candidate; the
higher-confidence copy wins. If two pages disagree about who won, the merge
still happens but the conflict is reported (stderr report + `conflicts` list
with `conflict_hint=True`) — never silently discarded.

## Known limitations

- Team IDs are season-specific; the CSV map must be regenerated per season.
- The parser is heuristic; if Trackwrestling changes markup substantially,
  add the new shape to `twparse.py` (the self-test is the regression net).
- Free-text summaries with unusual phrasing (no `over`/`def`/W-L marker)
  parse at confidence 0.4 with winner/loser `None` — review in the platform's
  `needs_review` queue rather than trusting them.
- An empty team page can mean "team did not participate" — not an error.

# Future Ideas (parked)

Not being worked on right now — current priority is finishing the core loop: create tournament → submit a full bracket prediction → enter results → verify scoring, using the real 2025 NCAA D1 championships data. Revisit these after that's solid.

## 1. Pick'em "Best Scenario" team recommender

After a user fully predicts the championship bracket, auto-generate a suggested pick'em roster from their own predictions instead of leaving value-hunting to manual spreadsheet work.

- **Insight:** cost is seed-based (`seed_costs` in `get_default_pickem_config`), points are placement-based (`placement_points` 1st–8th). A low seed predicted to place well (e.g. 10-seed → 3rd) is a high-value pick — cheap cost, big point payoff.
- **Data we already have:** `resolvePicks` (web/src/components/bracket/bracketMath.js) resolves the user's predicted outcome per weight class; `get_default_pickem_config` (functions/utils/get_default_pickem_config.xs) has `seed_costs` and `scoring` (placement + win points). No backend changes needed for a first pass.
- **Shape of the problem:** `pickem_pick` enforces exactly one wrestler per weight class per entry under a shared budget (1000) — this is a multiple-choice knapsack problem (one pick per weight-class group, total cost ≤ budget, maximize predicted points). Recommend an exact DP solve, not a greedy value/cost sort — problem size (~10-14 weight classes) makes DP trivial, and greedy can miss better combinations.
- **UI:** "Recommended" chips next to wrestlers in the pick'em builder; a "Generate Best Scenario" button pre-fills the roster (still fully editable).
- **Known gap:** predicted points can only include placement + win points, not bonus points (fall/tech-fall/major), since victory type isn't part of a plain "who wins" bracket pick. Closing that gap needs historical per-wrestler bonus-point rates — see #2.

## 2. TrackWrestling historical data integration (IN PROGRESS as of 2026-07-20)

Status: actively being built, not just planned. The original `tw.py`/`twclient.py` tooling (per-event/per-team HTML scraping) turned out to be built against an outdated site structure. A better data source was found: a team's "Results per Wrestler" page returns a wrestler's entire season (every dual + tournament) in one JSON call, and the same page embeds the full team roster (every wrestler id) inline — so the whole crawl only needs one page load per team plus one call per wrestler, no manual id lookup.

Built so far: `scripts/trackwrestling/twwrestlermatches.py` and `twroster.py` (parsers, validated against real captured data), plus new Xano tables `canonical_wrestler`, `canonical_team`, `wrestler_match_history`. Still needed: the actual fetcher (session/cookie handling — automatic bootstrap currently 406s, so a session token has to be grabbed manually from a browser for now) and the crawl orchestration tying it together. Full details in memory (`trackwrestling-historical-data-roadmap`) and in the docstrings at the top of the two parser modules.

Once fully wired up, it unlocks:
- Per-wrestler analytics (pin rate, tech-fall rate, etc.) — feeds #1's bonus-point estimate.
- Hover-over wrestler card on bracket views → modal with last ~10 match results + link to full wrestler profile in a new tab.
- Head-to-head surfacing: if two wrestlers in a matchup have faced each other before, show that history on the matchup card.

**Prerequisite (separate sub-project):** wrestler identity matching. PDF-imported bracket wrestlers need to be reconciled against the existing wrestler database (dedup/link to the same underlying wrestler record) before any historical record can reliably attach to the right person. This is its own scoped effort, distinct from the scraping work itself.

## 3. Season-long platform + freemium model (target: fall college wrestling season launch)

Big-picture business model and scope expansion, described 2026-07-20. Not scoped or started — this is a large effort (schedule ingestion, event data model, billing, season-aggregate scoring) that deserves its own planning pass with the Xano Development Planner when it's time to start.

- **Full D1 schedule ingestion:** load every Division I college wrestling schedule for the season — dual meets, dual tournaments, and individual tournaments all become playable "events" on the platform, not just standalone tournaments like the current NCAA D1 championships test case.
- **Schedule browser:** a new area of the app to view the full season schedule, filterable by team, or viewed as one overall calendar.
- **Freemium access model:** free tier = pick/predict on ~2-3 events (enough to invite friends, try it out, or just play a single marquee event like nationals for free). Paid tier = a flat annual "season pass" unlocking every event for the whole season.
- **Season-long leaderboard:** in addition to each individual event/tournament's own leaderboard, an aggregate season-wide leaderboard that rewards players for entering many events, not just one — the incentive structure for the paid season pass.

This implies the current single-tournament-scoped data model (tournament → weight_class → bracket_match, one entry per tournament) will need to grow into a multi-event-per-season structure with per-user season aggregation, plus payment/subscription and entitlement gating (which events a given account can access). Keep this in mind for any architecture decisions made in the meantime — avoid baking in assumptions that only one tournament exists at a time.

## 4. Fantasy-football-style head-to-head season league (builds on #3)

A gameplay mode that doesn't exist elsewhere in wrestling, described 2026-07-20. Distinct from the individual-event bracket/pick'em modes we're building now — this is a season-long, roster-management game played within a private group/pool.

- **Structure:** a group (pool) of players (e.g. 8), each drafting a roster with one starter per weight class. Head-to-head matchups pair two pool members against each other over a competitive window — likely 2 weeks at a time, since college wrestling events are infrequent compared to weekly team sports.
- **Roster management:** starters must actually be competing during that window to score. Players can trade with other pool members, or drop a wrestler to a waiver wire and pick up someone else at that weight for the period — a dropped wrestler becomes available for another pool member to claim.
- **Injury/bye handling:** a player can choose to leave an injured starter's spot scoring zero for a window rather than drop them, if the injury is short-term — but that wrestler remains on the waiver wire for others to pick up in the meantime.
- **Data dependency:** requires the season schedule + wrestler records/availability data (see #2 and #3) so players can see, for each available wrestler, when they compete next and who they're likely facing.
- **Scope:** regular-season-long fantasy flow, with a separate (not yet designed) postseason format.

This is a substantial standalone game mode (roster/draft mechanics, waiver wire, trades, head-to-head weekly/biweekly scoring, matchup scheduling within a pool) layered on top of the season-platform infrastructure in #3 — plan it as its own effort once the season-platform data model (schedule + historical records) exists.

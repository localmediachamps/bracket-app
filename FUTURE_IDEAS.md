# Future Ideas (parked)

Not being worked on right now — current priority is finishing the core loop: create tournament → submit a full bracket prediction → enter results → verify scoring, using the real 2025 NCAA D1 championships data. Revisit these after that's solid.

## 1. Pick'em "Best Scenario" team recommender

After a user fully predicts the championship bracket, auto-generate a suggested pick'em roster from their own predictions instead of leaving value-hunting to manual spreadsheet work.

- **Insight:** cost is seed-based (`seed_costs` in `get_default_pickem_config`), points are placement-based (`placement_points` 1st–8th). A low seed predicted to place well (e.g. 10-seed → 3rd) is a high-value pick — cheap cost, big point payoff.
- **Data we already have:** `resolvePicks` (web/src/components/bracket/bracketMath.js) resolves the user's predicted outcome per weight class; `get_default_pickem_config` (functions/utils/get_default_pickem_config.xs) has `seed_costs` and `scoring` (placement + win points). No backend changes needed for a first pass.
- **Shape of the problem:** `pickem_pick` enforces exactly one wrestler per weight class per entry under a shared budget (1000) — this is a multiple-choice knapsack problem (one pick per weight-class group, total cost ≤ budget, maximize predicted points). Recommend an exact DP solve, not a greedy value/cost sort — problem size (~10-14 weight classes) makes DP trivial, and greedy can miss better combinations.
- **UI:** "Recommended" chips next to wrestlers in the pick'em builder; a "Generate Best Scenario" button pre-fills the roster (still fully editable).
- **Known gap:** predicted points can only include placement + win points, not bonus points (fall/tech-fall/major), since victory type isn't part of a plain "who wins" bracket pick. Closing that gap needs historical per-wrestler bonus-point rates — see #2.

## 2. TrackWrestling historical data integration

Scripts already exist (`scripts/trackwrestling/tw.py`, `twclient.py`) for pulling TrackWrestling data; scraping the last couple seasons per wrestler hasn't been executed yet.

Once available, it unlocks:
- Per-wrestler analytics (pin rate, tech-fall rate, etc.) — feeds #1's bonus-point estimate.
- Hover-over wrestler card on bracket views → modal with last ~10 match results + link to full wrestler profile in a new tab.
- Head-to-head surfacing: if two wrestlers in a matchup have faced each other before, show that history on the matchup card.

**Prerequisite (separate sub-project):** wrestler identity matching. PDF-imported bracket wrestlers need to be reconciled against the existing wrestler database (dedup/link to the same underlying wrestler record) before any historical record can reliably attach to the right person. This is its own scoped effort, distinct from the scraping work itself.

// Discrete scoring windows on the season-global timeline. Four week types:
// head_to_head (normal week, scored via `matchup`/`lineup`, paired 1v1 - the
// result also converts to flat points in the same season_week_tournament_
// result ledger every other week type feeds); marquee_tournament (roster/
// lineup engine sits out entirely - a standalone pick'em/bracket/
// bracket_pickem contest against the linked tournament's full field,
// translated into fantasy points via season_week_tournament_result);
// conference and nationals (postseason - REDESIGNED 2026-07-22, see memory:
// conference_nationals_scoring_redesign - NOT head-to-head; each member
// scores their own roster with the same averaging math as head_to_head, all
// matches counting, then members are ranked against each other and awarded
// season-standings points from placement_points_config, same mechanism as
// marquee_tournament weeks. These weeks counting for more is entirely a
// function of their own placement table's values, not a separate weight
// field.)
table season_week {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? season_id? {
      table = "season"
    }

    int week_number
    timestamp starts_at
    timestamp ends_at

    enum week_type?="head_to_head" {
      values = ["head_to_head", "marquee_tournament", "conference", "nationals"]
    }

    enum status?="upcoming" {
      values = ["upcoming", "open", "locked", "scoring", "complete"]
    }

    // VESTIGIAL as of the 2026-07-22 postseason redesign - conference/
    // nationals weighting now comes entirely from placement_points_config's
    // own values (see the header comment), not a multiplier. Left in place
    // rather than dropped (no rows exist yet, but this mirrors the project's
    // own "don't destructively drop a field without being asked" convention
    // applied to bowl_assignment); no code reads this anymore.
    decimal weight_multiplier?=1

    // marquee_tournament weeks only - the real tournament this week is scored
    // against, and which contest mode the commissioner picked
    int? linked_tournament_id? {
      table = "tournament"
    }

    enum? tournament_game_mode? {
      values = ["pickem", "bracket", "bracket_pickem"]
    }

    // marquee_tournament OR conference/nationals weeks - commissioner's
    // per-week placement (rank) -> league-standings-points table, e.g. {"1":
    // 20, "2": 15, ..., "default": 0}. Deliberately per-week, not a shared
    // season config, since different weeks may warrant different weighting.
    // Falls back to get_default_league_config.xs's placement_points_defaults
    // (keyed by week_type) when left null. Set via leagues_week_config_PUT.xs
    // for marquee_tournament weeks, leagues_week_placement_config_PUT.xs for
    // conference/nationals weeks (different required inputs - marquee also
    // needs a linked tournament + game mode, conference/nationals don't).
    json? placement_points_config?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "season_id", op: "asc"}, {name: "week_number", op: "asc"}]}
    {type: "btree", field: [{name: "status", op: "asc"}]}
    {type: "btree", field: [{name: "ends_at", op: "asc"}]}
  ]
  guid = "bklVvMUgKRVmUpv-GxmawPWs1qU"
}

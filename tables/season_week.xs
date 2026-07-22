// Discrete scoring windows on the season-global timeline. Four week types:
// head_to_head (normal week, scored via `matchup`/`lineup`, paired 1v1);
// marquee_tournament (roster/lineup engine sits out entirely - a standalone
// pick'em/bracket/bracket_pickem contest against the linked tournament's full
// field, translated into fantasy points via season_week_tournament_result);
// conference and nationals (postseason - scored exactly like head_to_head off
// the member's existing roster, but with no opposing matchup and weighted via
// weight_multiplier when rolled into final standings - see the fantasy league
// plan's postseason redesign, 2026-07-22).
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

    // conference/nationals weeks only, config-sourced, capped per the
    // league's scoring_config - how much this week's result can swing the
    // final standings. marquee_tournament weeks use placement_points_config
    // instead, not this field.
    decimal weight_multiplier?=1

    // marquee_tournament weeks only - the real tournament this week is scored
    // against, and which contest mode the commissioner picked
    int? linked_tournament_id? {
      table = "tournament"
    }

    enum? tournament_game_mode? {
      values = ["pickem", "bracket", "bracket_pickem"]
    }

    // marquee_tournament weeks only - commissioner's per-tournament
    // placement (rank) -> league-standings-points table, e.g. {"1": 20, "2":
    // 15, ..., "default": 0}. Deliberately per-week, not a shared season
    // config, since different marquee weeks may warrant different weighting.
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

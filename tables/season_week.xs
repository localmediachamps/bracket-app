// Discrete scoring windows on the season-global timeline. head_to_head weeks
// use `matchup`/`lineup`; the other three week types all share the same
// 5-mode choice (commissioner-picked): roster (score the existing roster
// normally against this week's real results), bracket / pickem / bracket_pickem
// (full real-tournament field, results translated via
// season_week_tournament_result), or tournament_draft (a second, smaller
// mini-draft scoped to just this tournament's field - see `draft.season_week_id`).
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
      values = ["head_to_head", "regular_season_tournament", "bowl", "nationals"]
    }

    enum status?="upcoming" {
      values = ["upcoming", "open", "locked", "scoring", "complete"]
    }

    // Non-head_to_head weeks only, config-sourced, capped per the league's
    // scoring_config - how much this week's result can swing the standings
    decimal weight_multiplier?=1

    // Non-head_to_head weeks only - the real tournament this week is scored
    // against, and which of its two existing game modes the commissioner picked
    int? linked_tournament_id? {
      table = "tournament"
    }

    enum? tournament_game_mode? {
      values = ["roster", "bracket", "pickem", "bracket_pickem", "tournament_draft"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "season_id", op: "asc"}, {name: "week_number", op: "asc"}]}
    {type: "btree", field: [{name: "status", op: "asc"}]}
    {type: "btree", field: [{name: "ends_at", op: "asc"}]}
  ]
  guid = "bklVvMUgKRVmUpv-GxmawPWs1qU"
}

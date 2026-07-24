// Per-league override of a shared season_week - added 2026-07-24 because
// season_week (and its week_type/linked_tournament_id/tournament_game_mode/
// placement_points_config fields) is shared across every league in a
// season, but different leagues want independent control over which weeks
// are head-to-head vs. marquee tournament, and which real tournament a
// marquee week links to. Only ever created for a week whose SEASON-LEVEL
// (season_week.week_type) base type is "head_to_head" - conference/
// nationals stay universal, never overridden here. One row per (league,
// week) at most. Presence of a row means "this league diverges from the
// season default for this week"; absence means the league just uses
// season_week's own values unchanged.
table league_week_override {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? league_id? {
      table = "league"
    }

    int? season_week_id? {
      table = "season_week"
    }

    // Only "head_to_head" or "marquee_tournament" - this league's effective
    // type for this week, overriding season_week.week_type.
    enum week_type?="marquee_tournament" {
      values = ["head_to_head", "marquee_tournament"]
    }

    // marquee_tournament only - same meaning as season_week's own fields,
    // just scoped to this one league instead of shared.
    int? linked_tournament_id? {
      table = "tournament"
    }

    enum? tournament_game_mode? {
      values = ["pickem", "bracket", "bracket_pickem"]
    }

    json? placement_points_config?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "league_id", op: "asc"}, {name: "season_week_id", op: "asc"}]}
  ]
  guid = "Fq3wZm5EpUt7RjYnCa2LhOi4KkBw6"
}

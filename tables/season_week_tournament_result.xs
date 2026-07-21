// Per-league, per-tournament/bowl/nationals-week standings translation.
// Scoring for these weeks comes from a REAL tournament's own already-working
// leaderboard (rescore_tournament/rescore_pickem) - this table just records
// the translation of that leaderboard into fantasy standings points, ranked
// among just this league's own entrants (not the whole public field).
table season_week_tournament_result {
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

    int? membership_id? {
      table = "league_membership"
    }

    // This member's rank among just the league's own entrants
    int rank_in_league

    // placement_points[rank] x capped_weight_multiplier, from the league's
    // scoring_config
    decimal awarded_points?=0
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "league_id", op: "asc"}, {name: "season_week_id", op: "asc"}, {name: "membership_id", op: "asc"}]}
  ]
  guid = "_azlvwO4WxYb-zxuW-9Jwr5bdY0"
}

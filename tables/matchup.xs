// Per-league, per-week head-to-head pairing. head_to_head weeks only - the
// other three season_week types are scored via season_week_tournament_result
// instead, since everyone plays the same real tournament, not each other.
table matchup {
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

    int? home_membership_id? {
      table = "league_membership"
    }

    // Nullable - odd member counts get a bye
    int? away_membership_id? {
      table = "league_membership"
    }

    decimal home_points?
    decimal away_points?

    enum? result? {
      values = ["home", "away", "tie", "pending"]
    }

    enum status?="scheduled" {
      values = ["scheduled", "complete"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "league_id", op: "asc"}, {name: "season_week_id", op: "asc"}]}
  ]
  guid = "nsiOnJ2V3uqbyL7s3UI7mJk0UgY"
}

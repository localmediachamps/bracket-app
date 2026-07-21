// One per member per head_to_head scoring week - the locked active 10 for
// that week. points is the AVERAGE-per-match total (see lineup_slot), not a sum.
table lineup {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? league_id? {
      table = "league"
    }

    int? membership_id? {
      table = "league_membership"
    }

    int? matchup_id? {
      table = "matchup"
    }

    int? season_week_id? {
      table = "season_week"
    }

    enum status?="draft" {
      values = ["draft", "submitted", "locked", "scored"]
    }

    timestamp locked_at?
    decimal points?=0
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "league_id", op: "asc"}, {name: "membership_id", op: "asc"}, {name: "season_week_id", op: "asc"}]}
  ]
  guid = "5zL7_Y81FIgmPVNTZa874_5OJWw"
}

// One row per member once bowl season starts, assigning them to a
// conference tier based on regular-season standings - real college-football
// bowl-style seeding (best record -> most prestigious/toughest conference).
// Conference-competitiveness ranking itself is Garrett-supplied, not derived.
table bowl_assignment {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? league_id? {
      table = "league"
    }

    int? season_id? {
      table = "season"
    }

    int? membership_id? {
      table = "league_membership"
    }

    // e.g. "Big Ten", "ACC" - matches a key in league.bowl_config
    text conference_tier filters=trim

    // The regular-season standings rank that earned this bowl slot
    int regular_season_rank

    // The resulting bowl week, once created
    int? season_week_id? {
      table = "season_week"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "league_id", op: "asc"}, {name: "season_id", op: "asc"}, {name: "membership_id", op: "asc"}]}
  ]
  guid = "w3AnKOmPRyWsbSMz50DSZ5B14bE"
}

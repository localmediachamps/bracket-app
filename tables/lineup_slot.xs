// The 10 starters chosen for a lineup's week, snapshotted so later roster
// changes (waivers/trades) never rewrite scoring history. points is this
// wrestler's average-per-match score (with opponent-quality multiplier
// already applied per match, before averaging) plus any medal_bonus.
table lineup_slot {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? lineup_id? {
      table = "lineup"
    }

    int? season_weight_class_id? {
      table = "season_weight_class"
    }

    int? canonical_wrestler_id? {
      table = "canonical_wrestler"
    }

    decimal points?=0
    int match_count?=0
    decimal medal_bonus?=0

    // Per-match breakdown for UI transparency - victory type, opponent
    // quality tier, points contributed by each real match this week
    json? scoring_breakdown?

    bool competed?=false
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "lineup_id", op: "asc"}]}
    {type: "btree", field: [{name: "canonical_wrestler_id", op: "asc"}]}
  ]
  guid = "HA5hcDFj04xuUvIdxtsdFw9rbXc"
}

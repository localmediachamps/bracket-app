// Live, mutable roster state - draft_pick is the immutable history; this
// changes via waivers/trades. One active row per (league, wrestler).
table roster_slot {
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

    int? canonical_wrestler_id? {
      table = "canonical_wrestler"
    }

    int? season_weight_class_id? {
      table = "season_weight_class"
    }

    enum slot_type?="starter" {
      values = ["starter", "alternate"]
    }

    // Which alternate slot (1 or 2) when slot_type=alternate
    int? slot_index?

    enum status?="active" {
      values = ["active", "dropped"]
    }

    timestamp acquired_at?

    enum acquired_via?="draft" {
      values = ["draft", "waiver", "trade"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "league_id", op: "asc"}, {name: "membership_id", op: "asc"}]}
    {type: "btree", field: [{name: "canonical_wrestler_id", op: "asc"}]}
  ]
  guid = "ghb3PJIZqIsT_Bc6rCw_FuBd2YE"
}

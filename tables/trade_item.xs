// One wrestler moving as part of a trade. A trade has 2+ of these rows
// (at minimum one per side); executing the trade re-points the referenced
// roster_slot's membership_id to from_membership_id's counterpart.
table trade_item {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? trade_id? {
      table = "trade"
    }

    // Which member currently owns this wrestler (the side giving them up)
    int? from_membership_id? {
      table = "league_membership"
    }

    int? canonical_wrestler_id? {
      table = "canonical_wrestler"
    }

    int? roster_slot_id? {
      table = "roster_slot"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "trade_id", op: "asc"}]}
    {type: "btree", field: [{name: "roster_slot_id", op: "asc"}]}
  ]
  guid = "ksNXMmht1L5XHp979bPyeBZl_mY"
}

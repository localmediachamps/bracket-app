// Member-to-member trade proposal, negotiated in-app (not admin-mediated).
// The actual wrestlers moving each direction are in trade_item rows.
table trade {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? league_id? {
      table = "league"
    }

    int? proposer_membership_id? {
      table = "league_membership"
    }

    int? receiver_membership_id? {
      table = "league_membership"
    }

    enum status?="proposed" {
      values = ["proposed", "accepted", "rejected", "cancelled", "countered", "vetoed", "executed"]
    }

    timestamp? expires_at?

    // If this trade is a counter-offer to an earlier one
    int? counter_of_trade_id? {
      table = "trade"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "league_id", op: "asc"}, {name: "status", op: "asc"}]}
    {type: "btree", field: [{name: "proposer_membership_id", op: "asc"}]}
    {type: "btree", field: [{name: "receiver_membership_id", op: "asc"}]}
  ]
  guid = "81NUalwdSaz23hoGkn4LS_635bc"
}

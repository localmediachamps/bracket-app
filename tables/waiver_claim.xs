// Waiver-wire requests. A dropped or undrafted wrestler is claimable by any
// league member; resolution policy (instant first-come vs. batched priority)
// is still an open design question (see the fantasy league plan file).
table waiver_claim {
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

    // Which of the claimant's roster spots they'll drop to make room
    int? drop_roster_slot_id? {
      table = "roster_slot"
    }

    enum status?="pending" {
      values = ["pending", "awarded", "denied", "cancelled"]
    }

    timestamp submitted_at?

    // Priority ordering snapshot at submission time, if the league uses a
    // priority-based (not first-come) resolution policy
    int? priority_snapshot?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "league_id", op: "asc"}, {name: "status", op: "asc"}]}
    {type: "btree", field: [{name: "canonical_wrestler_id", op: "asc"}]}
  ]
  guid = "qroez-V4Bj6Eru-jchsdQXWkvKE"
}

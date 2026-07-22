// One user's set of picks for one dual_meet. Scored via a fixed rubric
// (correct-count tiers), not percentile against the field - see
// dual_rubric_scoring_design memory and functions/scoring/rescore_dual_meet.xs.
table dual_meet_entry {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int dual_meet_id {
      table = "dual_meet"
    }

    int user_id {
      table = "user"
    }

    // draft | submitted | locked | scored
    text status?=draft

    // Owner opt-in to let other users view this entry's picks. Defaults to
    // private, same convention as user_bracket/pickem_entry.
    bool is_public?=false

    timestamp? submitted_at?
    timestamp? locked_at?

    // Populated at scoring time
    int? correct_winner_count?
    int? correct_type_count?
    int? occurred_weight_count?
    text? rubric_tier?
    decimal total_points?=0

    int? rank?
    int? prev_rank?

    timestamp updated_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "dual_meet_id", op: "asc"}
        {name: "user_id", op: "asc"}
      ]
    }
    {type: "btree", field: [{name: "dual_meet_id", op: "asc"}]}
    {type: "btree", field: [{name: "total_points", op: "desc"}]}
  ]
  guid = "aTUtTv7COicLJxCyU6bkuaWhrjs"
}

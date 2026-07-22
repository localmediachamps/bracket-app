// A single weight-class pick within a dual_meet_entry: which side wins, and
// how (victory type). is_correct_winner/is_correct_type are populated at
// scoring time so the UI can show a per-weight breakdown without recomputing.
table dual_meet_pick {
  auth = false

  schema {
    int id

    int entry_id {
      table = "dual_meet_entry"
    }

    int weight_slot_id {
      table = "dual_meet_weight_slot"
    }

    // "home" | "away"
    text picked_side

    // decision|major|tech_fall|fall|medical_forfeit|injury_default|forfeit|
    // disqualification - same vocabulary as bracket_match.victory_type
    text? picked_victory_type?

    bool? is_correct_winner?
    bool? is_correct_type?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "entry_id", op: "asc"}
        {name: "weight_slot_id", op: "asc"}
      ]
    }
    {type: "btree", field: [{name: "entry_id", op: "asc"}]}
  ]
  guid = "1o43j8a8hpdvd_Ckm0m5bMJa9Yw"
}

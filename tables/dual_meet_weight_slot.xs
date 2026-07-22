// One weight class within a dual_meet. actual_winner_side/actual_victory_type
// are the real result - the "answer key" - always populated at creation time
// (even for a future real dual, once results come in), but never exposed to
// users via the public API until the dual meet is locked/scored. occurred
// tracks the weight-nullification rule: a predicted weight whose match never
// actually happens (injury default swap, forfeit of the whole weight, etc.)
// is excluded from both the numerator and denominator when scoring, not
// counted as a miss - see functions/scoring/rescore_dual_meet.xs.
table dual_meet_weight_slot {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int dual_meet_id {
      table = "dual_meet"
    }

    int weight
    int display_order?

    text? home_wrestler_name? filters=trim
    text? away_wrestler_name? filters=trim

    int? home_canonical_wrestler_id? {
      table = "canonical_wrestler"
    }

    int? away_canonical_wrestler_id? {
      table = "canonical_wrestler"
    }

    // "home" | "away" - null until the result is known
    text? actual_winner_side?

    // Normalized victory type (decision|major|tech_fall|fall|medical_forfeit|
    // injury_default|forfeit|disqualification) via normalize_victory_type.xs
    text? actual_victory_type?

    // Did this weight's match actually happen at all - false/null means
    // nullified (excluded from scoring entirely), not scored as a miss
    bool? occurred?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "dual_meet_id", op: "asc"}]}
  ]
  guid = "qMIhD0G33sEP7_lQxocXp2JG850"
}

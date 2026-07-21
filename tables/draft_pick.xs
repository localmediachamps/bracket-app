// Immutable draft audit trail - one row per pick made (or auto-picked).
// For the preseason draft, roster_slot is the live/mutable roster state
// mirroring these picks; this never changes after the fact even if the
// wrestler is later traded or dropped. For a tournament mini-draft
// (draft.season_week_id set), THIS TABLE IS THE ONLY RECORD - no roster_slot
// is ever written, so the season-long roster is untouched and simply
// continues as before once the tournament week ends.
//
// Exclusivity ("can't draft the same wrestler twice") is scoped to one
// draft_id, not league-wide - the same wrestler is expected to appear in
// both their owner's permanent draft_pick row AND a later tournament
// mini-draft's draft_pick row; those are different draft_id values.
table draft_pick {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? draft_id? {
      table = "draft"
    }

    int? league_id? {
      table = "league"
    }

    int? membership_id? {
      table = "league_membership"
    }

    int? canonical_wrestler_id? {
      table = "canonical_wrestler"
    }

    int overall_pick_number
    int round_number

    // Preseason draft only - the season-wide weight class chosen for this pick.
    int? season_weight_class_id? {
      table = "season_weight_class"
    }

    // Real lbs value (125/133/.../285), populated for BOTH contexts - the
    // preseason draft copies it from season_weight_class.weight, a
    // tournament mini-draft copies it from the tournament's own
    // weight_class.weight via the picked wrestler row. This is the portable
    // "one per weight" key across both weight-class tables.
    int? weight?

    enum pick_type?="manual" {
      values = ["manual", "autopick", "timeout_autopick"]
    }

    timestamp picked_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "draft_id", op: "asc"}, {name: "canonical_wrestler_id", op: "asc"}]}
    {type: "btree", field: [{name: "draft_id", op: "asc"}]}
    {type: "btree", field: [{name: "league_id", op: "asc"}]}
    {type: "btree", field: [{name: "membership_id", op: "asc"}]}
  ]
  guid = "gcQmpMLiGp6b2MPht5fMmIOTqeU"
}

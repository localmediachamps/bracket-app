// Submit a dual meet entry: every weight slot must have a pick.
query "dual-meet-entries/{id}/submit" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // Dual meet entry id
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get dual_meet_entry {
      field_name = "id"
      field_value = $input.id
    } as $entry

    precondition ($entry != null) {
      error_type = "notfound"
      error = "Dual meet entry not found."
    }

    precondition ($entry.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "You do not own this entry."
    }

    db.get dual_meet {
      field_name = "id"
      field_value = $entry.dual_meet_id
    } as $dual_meet

    precondition ($dual_meet != null) {
      error_type = "notfound"
      error = "Dual meet not found."
    }

    precondition (($entry.status == "draft" || $entry.status == "submitted") && $dual_meet.status == "open") {
      error_type = "inputerror"
      error = "Entry is not editable."
    }

    db.query dual_meet_weight_slot {
      where = $db.dual_meet_weight_slot.dual_meet_id == $dual_meet.id
      return = {type: "count"}
    } as $slot_count

    db.query dual_meet_pick {
      where = $db.dual_meet_pick.entry_id == $entry.id
      return = {type: "count"}
    } as $pick_count

    precondition ($slot_count > 0 && $pick_count >= $slot_count) {
      error_type = "inputerror"
      error = "INCOMPLETE: every weight class must have a pick."
    }

    db.edit dual_meet_entry {
      field_name = "id"
      field_value = $entry.id
      data = {
        status      : "submitted"
        submitted_at: now
        updated_at  : now
      }
    } as $updated_entry
  }

  response = $updated_entry
  guid = "QFvO1T-CMkgS4U61MNmV3vfvXRo"
}

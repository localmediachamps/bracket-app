// Replace all picks on a dual meet entry. Validates: one pick per weight
// slot of the dual meet, slot belongs to this dual meet, picked_side is
// home or away.
query "dual-meet-entries/{id}" verb=PUT {
  api_group = "brackets"
  auth = "user"

  input {
    // Dual meet entry id
    int id

    // Full pick set: [{weight_slot_id, picked_side, picked_victory_type?}]
    json picks
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

    var $seen_slots {
      value = []
    }

    var $validated_picks {
      value = []
    }

    foreach ($input.picks) {
      each as $pick {
        precondition (($seen_slots|some:$$ == $pick.weight_slot_id) == false) {
          error_type = "inputerror"
          error = "Only one pick per weight class is allowed."
        }

        array.push $seen_slots {
          value = $pick.weight_slot_id
        }

        precondition ($pick.picked_side == "home" || $pick.picked_side == "away") {
          error_type = "inputerror"
          error = "picked_side must be home or away."
        }

        db.get dual_meet_weight_slot {
          field_name = "id"
          field_value = $pick.weight_slot_id
        } as $slot

        precondition ($slot != null && $slot.dual_meet_id == $dual_meet.id) {
          error_type = "inputerror"
          error = "Invalid weight slot."
        }

        array.push $validated_picks {
          value = {
            weight_slot_id    : $slot.id
            picked_side       : $pick.picked_side
            picked_victory_type: $pick|get:"picked_victory_type":null
          }
        }
      }
    }

    // Replace all picks: delete existing, insert the validated set
    db.query dual_meet_pick {
      where = $db.dual_meet_pick.entry_id == $entry.id
      return = {type: "list"}
    } as $old_picks

    foreach ($old_picks) {
      each as $old_pick {
        db.del dual_meet_pick {
          field_name = "id"
          field_value = $old_pick.id
        }
      }
    }

    foreach ($validated_picks) {
      each as $validated {
        db.add dual_meet_pick {
          data = {
            entry_id          : $entry.id
            weight_slot_id     : $validated.weight_slot_id
            picked_side        : $validated.picked_side
            picked_victory_type: $validated.picked_victory_type
          }
        } as $new_pick
      }
    }

    db.edit dual_meet_entry {
      field_name = "id"
      field_value = $entry.id
      data = {updated_at: now}
    } as $updated_entry
  }

  response = $updated_entry
  guid = "riODerTkYtrKiq2HOY32tyE8L0k"
}

// Dual meet entry detail: entry plus picks with weight slot info. Viewable
// by the owner, any other logged-in user when the entry has opted into
// is_public, or a site admin. Requires login even for the is_public case,
// same rule as every other entry-viewing endpoint on this platform.
query "dual-meet-entries/{id}" verb=GET {
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

    var $is_owner {
      value = $entry.user_id == $auth.id
    }

    var $can_view {
      value = $is_owner || $entry.is_public
    }

    conditional {
      if ($can_view == false) {
        db.get user {
          field_name = "id"
          field_value = $auth.id
          output = ["id", "is_admin"]
        } as $requester

        conditional {
          if ($requester != null && $requester.is_admin) {
            var.update $can_view {
              value = true
            }
          }
        }
      }
    }

    precondition ($can_view) {
      error_type = "accessdenied"
      error = "This entry is private."
    }

    db.get user {
      field_name = "id"
      field_value = $entry.user_id
      output = ["id", "username", "display_name", "avatar_url"]
    } as $entry_user

    db.get dual_meet {
      field_name = "id"
      field_value = $entry.dual_meet_id
    } as $dual_meet

    var $reveal {
      value = $dual_meet != null && $dual_meet.status == "completed"
    }

    db.query dual_meet_pick {
      where = $db.dual_meet_pick.entry_id == $entry.id
      return = {type: "list"}
    } as $picks

    var $pick_rows {
      value = []
    }

    foreach ($picks) {
      each as $p {
        db.get dual_meet_weight_slot {
          field_name = "id"
          field_value = $p.weight_slot_id
        } as $slot

        var $slot_weight {
          value = null
        }

        var $slot_home_name {
          value = null
        }

        var $slot_away_name {
          value = null
        }

        var $slot_actual_side {
          value = null
        }

        var $slot_actual_type {
          value = null
        }

        conditional {
          if ($slot != null) {
            var.update $slot_weight {
              value = $slot.weight
            }

            var.update $slot_home_name {
              value = $slot.home_wrestler_name
            }

            var.update $slot_away_name {
              value = $slot.away_wrestler_name
            }

            var.update $slot_actual_side {
              value = $slot.actual_winner_side
            }

            var.update $slot_actual_type {
              value = $slot.actual_victory_type
            }
          }
        }

        var $row {
          value = {
            id                 : $p.id
            weight_slot_id     : $p.weight_slot_id
            weight             : $slot_weight
            home_wrestler_name : $slot_home_name
            away_wrestler_name : $slot_away_name
            picked_side        : $p.picked_side
            picked_victory_type: $p.picked_victory_type
          }
        }

        conditional {
          if ($reveal) {
            var.update $row {
              value = $row
                |set:"is_correct_winner":$p.is_correct_winner
                |set:"is_correct_type":$p.is_correct_type
                |set:"actual_winner_side":$slot_actual_side
                |set:"actual_victory_type":$slot_actual_type
            }
          }
        }

        array.push $pick_rows {
          value = $row
        }
      }
    }
  }

  response = {entry: $entry, dual_meet: $dual_meet, user: $entry_user, is_owner: $is_owner, picks: $pick_rows}
  guid = "j-JwTCAyWizYIpLNB-aMkInpNaw"
}

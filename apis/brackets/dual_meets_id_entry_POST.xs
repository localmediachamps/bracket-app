// Get-or-create the current user's entry for a dual meet.
query "dual-meets/{id}/entry" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // Dual meet id
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get dual_meet {
      field_name = "id"
      field_value = $input.id
    } as $dual_meet

    precondition ($dual_meet != null) {
      error_type = "notfound"
      error = "Dual meet not found."
    }

    db.query dual_meet_entry {
      where = $db.dual_meet_entry.user_id == $auth.id && $db.dual_meet_entry.dual_meet_id == $input.id
      return = {type: "single"}
    } as $existing

    var $entry {
      value = $existing
    }

    conditional {
      if ($existing == null) {
        precondition ($dual_meet.status == "open") {
          error_type = "badrequest"
          error = "Dual meet is not open for entries."
        }

        db.add dual_meet_entry {
          data = {
            created_at  : now
            user_id     : $auth.id
            dual_meet_id: $input.id
            status      : "draft"
            total_points: 0
            updated_at  : now
          }
        } as $new_entry

        var.update $entry {
          value = $new_entry
        }
      }
    }
  }

  response = $entry
  guid = "fNvrgRRQ5Nm1Z8yTE0tLZiI-r44"
}

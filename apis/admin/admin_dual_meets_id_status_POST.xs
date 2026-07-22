// Dual meet state machine transitions. Actions:
//   lock (open->locked): locks every draft|submitted entry, stops further edits.
//   score (locked->completed): runs rescore_dual_meet (reveals the real
//     results and grades every entry against the rubric), then completes.
//   reopen (locked->open, reason required): unlocks for further edits.
query "admin/dual-meets/{id}/status" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Dual meet id
    int id

    // lock | score | reopen
    text action filters=trim|lower

    // Required for reopen
    text? reason? filters=trim
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    precondition ($input.action == "lock" || $input.action == "score" || $input.action == "reopen") {
      error_type = "inputerror"
      error = "action must be one of: lock, score, reopen."
    }

    conditional {
      if ($input.action == "reopen") {
        precondition ($input.reason != null && ($input.reason|strlen) > 0) {
          error_type = "inputerror"
          error = "reason is required to reopen a dual meet."
        }
      }
    }

    db.get dual_meet {
      field_name = "id"
      field_value = $input.id
    } as $dual_meet

    precondition ($dual_meet != null) {
      error_type = "notfound"
      error = "Dual meet not found."
    }

    var $new_status {
      value = null
    }

    var $locked_entries {
      value = 0
    }

    var $rescore_summary {
      value = null
    }

    conditional {
      if ($input.action == "lock") {
        precondition ($dual_meet.status == "open") {
          error_type = "inputerror"
          error = "Only open dual meets can be locked (current: " ~ $dual_meet.status ~ ")."
        }

        var.update $new_status {
          value = "locked"
        }

        db.query dual_meet_entry {
          where = $db.dual_meet_entry.dual_meet_id == $input.id && ($db.dual_meet_entry.status == "draft" || $db.dual_meet_entry.status == "submitted")
          return = {type: "list"}
        } as $open_entries

        foreach ($open_entries) {
          each as $entry {
            db.edit dual_meet_entry {
              field_name = "id"
              field_value = $entry.id
              data = {status: "locked", locked_at: now, updated_at: now}
            } as $locked_entry

            math.add $locked_entries {
              value = 1
            }
          }
        }
      }

      elseif ($input.action == "score") {
        precondition ($dual_meet.status == "locked") {
          error_type = "inputerror"
          error = "Only locked dual meets can be scored (current: " ~ $dual_meet.status ~ ")."
        }

        function.run rescore_dual_meet {
          input = {dual_meet_id: $input.id}
        } as $rescore_result

        var.update $rescore_summary {
          value = $rescore_result
        }

        var.update $new_status {
          value = "completed"
        }
      }

      elseif ($input.action == "reopen") {
        precondition ($dual_meet.status == "locked") {
          error_type = "inputerror"
          error = "Only locked dual meets can be reopened (current: " ~ $dual_meet.status ~ ")."
        }

        var.update $new_status {
          value = "open"
        }
      }
    }

    db.edit dual_meet {
      field_name = "id"
      field_value = $input.id
      data = {status: $new_status}
    } as $updated

    function.run audit {
      input = {
        actor_id      : $auth.id
        entity_type   : "dual_meet"
        entity_id     : $input.id
        action        : $input.action
        previous_value: {status: $dual_meet.status}
        new_value     : {status: $new_status}
        metadata      : {}|set_ifnotnull:"reason":$input.reason
      }
    } as $audit_row
  }

  response = {
    dual_meet     : $updated
    action        : $input.action
    status        : $new_status
    locked_entries: $locked_entries
    rescore       : $rescore_summary
  }
  guid = "ZY6SDGkSzqnhuTqEpfc0udvfJOs"
}

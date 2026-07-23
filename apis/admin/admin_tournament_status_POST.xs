// Tournament state machine transitions (ARCHITECTURE.md sections 4 and 6).
// Actions: lock (open->locked), unlock|start (locked->live), complete (live->completed),
// archive (completed->archived), reopen (locked|live->open, reason required), cancel (any->cancelled).
// lock: locks all draft|submitted bracket + pickem entries and notifies entry owners.
// complete: requires every match complete|corrected|cancelled, runs a final rescore,
// and notifies entrants. Every transition writes an audit row.
query "admin/tournaments/{id}/status" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  
    // lock | unlock | start | complete | archive | reopen | cancel
    text action filters=trim|lower
  
    // Required for reopen; recorded in the audit log for any action
    text? reason? filters=trim
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    precondition ($input.action == "lock" || $input.action == "unlock" || $input.action == "start" || $input.action == "complete" || $input.action == "archive" || $input.action == "reopen" || $input.action == "cancel") {
      error_type = "inputerror"
      error = "action must be one of: lock, unlock, start, complete, archive, reopen, cancel."
    }
  
    conditional {
      if ($input.action == "reopen") {
        precondition ($input.reason != null) {
          error_type = "inputerror"
          error = "reason is required to reopen a tournament."
        }
      
        precondition (($input.reason|strlen) > 0) {
          error_type = "inputerror"
          error = "reason is required to reopen a tournament."
        }
      }
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    var $new_status {
      value = null
    }
  
    var $locked_entries {
      value = 0
    }
  
    var $notify_ids {
      value = []
    }
  
    var $notify_type {
      value = null
    }
  
    var $notify_title {
      value = null
    }
  
    var $did_rescore {
      value = false
    }
  
    var $rescore_summary {
      value = null
    }
  
    conditional {
      if ($input.action == "lock") {
        precondition ($tournament.status == "open") {
          error_type = "inputerror"
          error = "Only open tournaments can be locked (current: " ~ $tournament.status ~ ")."
        }
      
        var.update $new_status {
          value = "locked"
        }
      
        // Lock every editable bracket entry
        db.query user_bracket {
          where = $db.user_bracket.tournament_id == $input.id && ($db.user_bracket.status == "draft" || $db.user_bracket.status == "submitted")
          return = {type: "list"}
        } as $open_entries
      
        foreach ($open_entries) {
          each as $entry {
            db.edit user_bracket {
              field_name = "id"
              field_value = $entry.id
              data = {status: "locked", locked_at: now, updated_at: now}
            } as $locked_entry
          
            math.add $locked_entries {
              value = 1
            }
          
            conditional {
              if (($notify_ids|some:$$ == $entry.user_id) == false) {
                array.push $notify_ids {
                  value = $entry.user_id
                }
              }
            }
          }
        }
      
        // Lock every editable pick'em entry
        db.query pickem_entry {
          where = $db.pickem_entry.tournament_id == $input.id && ($db.pickem_entry.status == "draft" || $db.pickem_entry.status == "submitted")
          return = {type: "list"}
        } as $open_pickem_entries
      
        foreach ($open_pickem_entries) {
          each as $pentry {
            db.edit pickem_entry {
              field_name = "id"
              field_value = $pentry.id
              data = {status: "locked", locked_at: now, updated_at: now}
            } as $locked_pentry
          
            conditional {
              if (($notify_ids|some:$$ == $pentry.user_id) == false) {
                array.push $notify_ids {
                  value = $pentry.user_id
                }
              }
            }
          }
        }
      
        var.update $notify_type {
          value = "entry_locked"
        }
      
        var.update $notify_title {
          value = "Tournament locked: " ~ $tournament.name
        }
      }
    
      elseif ($input.action == "unlock" || $input.action == "start") {
        precondition ($tournament.status == "locked") {
          error_type = "inputerror"
          error = "Only locked tournaments can be started (current: " ~ $tournament.status ~ ")."
        }
      
        var.update $new_status {
          value = "live"
        }
      }
    
      elseif ($input.action == "complete") {
        precondition ($tournament.status == "live") {
          error_type = "inputerror"
          error = "Only live tournaments can be completed (current: " ~ $tournament.status ~ ")."
        }
      
        db.query bracket_match {
          where = $db.bracket_match.tournament_id == $input.id && $db.bracket_match.match_status != "complete" && $db.bracket_match.match_status != "corrected" && $db.bracket_match.match_status != "cancelled"
          return = {type: "count"}
        } as $incomplete_count
      
        precondition ($incomplete_count == 0) {
          error_type = "inputerror"
          error = "Cannot complete: " ~ ($incomplete_count|to_text) ~ " match(es) are not complete, corrected, or cancelled."
        }
      
        var.update $new_status {
          value = "completed"
        }
      }
    
      elseif ($input.action == "archive") {
        precondition ($tournament.status == "completed") {
          error_type = "inputerror"
          error = "Only completed tournaments can be archived (current: " ~ $tournament.status ~ ")."
        }
      
        var.update $new_status {
          value = "archived"
        }
      }
    
      elseif ($input.action == "reopen") {
        precondition ($tournament.status == "locked" || $tournament.status == "live") {
          error_type = "inputerror"
          error = "Only locked or live tournaments can be reopened (current: " ~ $tournament.status ~ ")."
        }
      
        var.update $new_status {
          value = "open"
        }
      }
    
      elseif ($input.action == "cancel") {
        precondition ($tournament.status != "cancelled") {
          error_type = "inputerror"
          error = "Tournament is already cancelled."
        }
      
        var.update $new_status {
          value = "cancelled"
        }
      }
    }
  
    db.edit tournament {
      field_name = "id"
      field_value = $input.id
      data = {status: $new_status}
    } as $updated
  
    // Complete: final idempotent rescore, then collect entrants for notification
    conditional {
      if ($input.action == "complete") {
        function.run rescore_tournament {
          input = {tournament_id: $input.id}
        } as $rescore_result
      
        var.update $did_rescore {
          value = true
        }
      
        var.update $rescore_summary {
          value = $rescore_result
        }
      
        db.query user_bracket {
          where = $db.user_bracket.tournament_id == $input.id
          return = {type: "list"}
          output = ["user_id"]
        } as $all_entries
      
        foreach ($all_entries) {
          each as $e {
            conditional {
              if (($notify_ids|some:$$ == $e.user_id) == false) {
                array.push $notify_ids {
                  value = $e.user_id
                }
              }
            }
          }
        }
      
        db.query pickem_entry {
          where = $db.pickem_entry.tournament_id == $input.id
          return = {type: "list"}
          output = ["user_id"]
        } as $all_pickem
      
        foreach ($all_pickem) {
          each as $pe {
            conditional {
              if (($notify_ids|some:$$ == $pe.user_id) == false) {
                array.push $notify_ids {
                  value = $pe.user_id
                }
              }
            }
          }
        }
      
        var.update $notify_type {
          value = "tournament_completed"
        }

        var.update $notify_title {
          value = "Tournament completed: " ~ $tournament.name
        }

        try_catch {
          try {
            function.run award_tournament_trophies {
              input = {tournament_id: $input.id, tournament_name: $tournament.name}
            } as $trophy_result
          }

          catch {
          }
        }
      }
    }
  
    var $notified {
      value = 0
    }
  
    conditional {
      if ($notify_type != null && ($notify_ids|count) > 0) {
        function.run notify {
          input = {
            user_ids: $notify_ids
            type    : $notify_type
            title   : $notify_title
            data    : {tournament_id: $input.id}
          }
        } as $notify_count
      
        var.update $notified {
          value = $notify_count
        }
      }
    }
  
    var $audit_metadata {
      value = {}
        |set_ifnotnull:"reason":$input.reason
    }
  
    function.run audit {
      input = {
        actor_id      : $auth.id
        entity_type   : "tournament"
        entity_id     : $input.id
        action        : $input.action
        previous_value: {status: $tournament.status}
        new_value     : {status: $new_status}
        metadata      : $audit_metadata
      }
    } as $audit_row
  }

  response = {
    tournament    : $updated
    action        : $input.action
    status        : $new_status
    locked_entries: $locked_entries
    notified      : $notified
    rescored      : $did_rescore
    rescore       : $rescore_summary
  }
  guid = "_OJSkh7JIDhpERaEQmBqfHgqpUg"
}
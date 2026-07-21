// Submit an entry: validates every non-bye match in the tournament has a pick.
// Fails with inputerror "INCOMPLETE:<count>" listing the number of missing picks.
// Success marks the entry submitted (still editable until the tournament locks).
query "entries/{id}/submit" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // Entry id
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.get user_bracket {
      field_name = "id"
      field_value = $input.id
    } as $entry
  
    precondition ($entry != null) {
      error_type = "notfound"
      error = "Entry not found."
    }
  
    precondition ($entry.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "You do not own this entry."
    }

    // Free-tier cap only applies to a genuinely new submission - re-saving
    // picks on an already-submitted entry doesn't use another slot.
    conditional {
      if ($entry.is_submitted != true) {
        function.run check_submission_cap {
          input = {user_id: $auth.id, tournament_id: $entry.tournament_id}
        } as $cap

        precondition ($cap.allowed) {
          error_type = "accessdenied"
          error = "Free plan is limited to " ~ ($cap.limit|to_text) ~ " submitted entries total. Upgrade to the annual plan for unlimited entries."
        }
      }
    }

    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $entry.tournament_id && $db.bracket_match.is_bye == false
      return = {type: "list"}
    } as $matches
  
    db.query user_pick {
      where = $db.user_pick.user_bracket_id == $entry.id
      return = {type: "list"}
    } as $picks
  
    var $picked_match_ids {
      value = $picks|map:$$.bracket_match_id
    }
  
    var $missing {
      value = []
    }
  
    foreach ($matches) {
      each as $m {
        conditional {
          if (($picked_match_ids|some:$$ == $m.id) == false) {
            array.push $missing {
              value = $m.id
            }
          }
        }
      }
    }
  
    var $missing_count {
      value = $missing|count
    }
  
    var $missing_word {
      value = "matches"
    }
  
    conditional {
      if ($missing_count == 1) {
        var.update $missing_word {
          value = "match"
        }
      }
    }
  
    precondition ($missing_count == 0) {
      error_type = "inputerror"
      error = $missing_count ~ " " ~ $missing_word ~ " still need picks before you can submit."
    }
  
    db.edit user_bracket {
      field_name = "id"
      field_value = $entry.id
      data = {
        status      : "submitted"
        is_submitted: true
        submitted_at: now
        updated_at  : now
      }
    } as $updated_entry
  }

  response = {entry: $updated_entry, missing: []}
  guid = "X1Ie5LLRGFZ8anqRhYpXRoSiPqU"
}
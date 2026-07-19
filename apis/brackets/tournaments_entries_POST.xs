// Get-or-create the current user's bracket entry for a tournament.
// Creation requires the tournament to be open (or allow_late_entries while
// locked/live). Existing entries are always returned. Increments entry_count.
query "tournaments/{id}/entries" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // Tournament id
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    db.query user_bracket {
      where = $db.user_bracket.user_id == $auth.id && $db.user_bracket.tournament_id == $input.id
      return = {type: "single"}
    } as $existing
  
    var $entry {
      value = $existing
    }
  
    conditional {
      if ($existing == null) {
        precondition ($tournament.status == "open" || ($tournament.allow_late_entries && ($tournament.status == "locked" || $tournament.status == "live"))) {
          error_type = "badrequest"
          error = "Tournament is not open for entries."
        }
      
        // Snapshot the scoring config version at entry creation
        var $scoring_version {
          value = 1
        }
      
        conditional {
          if ($tournament.scoring_config != null && ($tournament.scoring_config|has:"version")) {
            var.update $scoring_version {
              value = $tournament.scoring_config|get:"version"
            }
          }
        }
      
        db.add user_bracket {
          data = {
            created_at        : now
            user_id           : $auth.id
            tournament_id     : $input.id
            total_points      : 0
            is_submitted      : false
            status            : "draft"
            possible_points   : 0
            correct_pick_count: 0
            scored_pick_count : 0
            champions_correct : 0
            finalists_correct : 0
            scoring_version   : $scoring_version
            updated_at        : now
          }
        } as $new_entry
      
        db.edit tournament {
          field_name = "id"
          field_value = $input.id
          data = {entry_count: ($tournament.entry_count + 1)}
        } as $tournament_updated
      
        var.update $entry {
          value = $new_entry
        }
      }
    }
  }

  response = $entry
}
// Get-or-create the current user's pick'em entry for a tournament (same
// open-status rules as bracket entries).
query "tournaments/{id}/pickem" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // Tournament id
    int id
  }

  stack {
    precondition ($auth[""] != null) {
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
  
    db.query pickem_entry {
      where = $db.pickem_entry.user_id == $auth.id && $db.pickem_entry.tournament_id == $input.id
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
      
        db.add pickem_entry {
          data = {
            created_at   : now
            user_id      : $auth.id
            tournament_id: $input.id
            status       : "draft"
            points_used  : 0
            total_points : 0
            updated_at   : now
          }
        } as $new_entry
      
        var.update $entry {
          value = $new_entry
        }
      }
    }
  }

  response = $entry
}
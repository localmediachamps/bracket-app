// Submit or update a pick for a bracket match.
query "brackets/pick" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // User bracket ID
    int user_bracket_id
  
    // Bracket match ID
    int bracket_match_id
  
    // ID of the wrestler being picked as winner
    int picked_wrestler_id
  }

  stack {
    db.get user_bracket {
      field_name = "id"
      field_value = $input.user_bracket_id
    } as $user_bracket
  
    precondition ($user_bracket != null) {
      error_type = "notfound"
      error = "User bracket not found."
    }
  
    precondition ($user_bracket.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "You do not own this bracket."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $user_bracket.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    precondition ($tournament.status != "locked" && $tournament.status != "completed") {
      error_type = "badrequest"
      error = "Picks are not allowed — tournament is locked or completed."
    }
  
    db.query user_pick {
      where = $db.user_pick.user_bracket_id == $input.user_bracket_id && $db.user_pick.bracket_match_id == $input.bracket_match_id
      return = {type: "single"}
    } as $existing_pick
  
    var $pick_result {
      value = null
    }
  
    conditional {
      if ($existing_pick != null) {
        db.edit user_pick {
          field_name = "id"
          field_value = $existing_pick.id
          data = {
            picked_wrestler_id: $input.picked_wrestler_id
            updated_at        : now
            is_correct        : null
            points_earned     : null
          }
        } as $updated_pick
      
        var.update $pick_result {
          value = $updated_pick
        }
      }
    
      else {
        db.add user_pick {
          data = {
            created_at        : now
            updated_at        : now
            user_bracket_id   : $input.user_bracket_id
            user_id           : $auth.id
            tournament_id     : $user_bracket.tournament_id
            bracket_match_id  : $input.bracket_match_id
            picked_wrestler_id: $input.picked_wrestler_id
          }
        } as $new_pick
      
        var.update $pick_result {
          value = $new_pick
        }
      }
    }
  }

  response = $pick_result
}
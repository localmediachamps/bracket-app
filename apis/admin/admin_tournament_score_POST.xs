// Score all user brackets for a tournament and recompute rankings. Admin only.
query "admin/tournament/{id}/score" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin_check
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    db.query user_bracket {
      where = $db.user_bracket.tournament_id == $input.id
      return = {type: "list"}
    } as $brackets
  
    var $scored_count {
      value = 0
    }
  
    foreach ($brackets) {
      each as $bracket {
        function.run score_user_bracket {
          input = {user_bracket_id: $bracket.id, tournament_id: $input.id}
        } as $score_result
      
        math.add $scored_count {
          value = 1
        }
      }
    }
  
    // Recompute rankings by total_points descending
    db.query user_bracket {
      where = $db.user_bracket.tournament_id == $input.id
      sort = {user_bracket.total_points: "desc"}
      return = {type: "list"}
    } as $ranked_brackets
  
    var $rank_index {
      value = 0
    }
  
    foreach ($ranked_brackets) {
      each as $rb {
        math.add $rank_index {
          value = 1
        }
      
        db.edit user_bracket {
          field_name = "id"
          field_value = $rb.id
          data = {rank: $rank_index}
        } as $ranked_bracket
      }
    }
  }

  response = {scored_brackets: $scored_count, tournament_id: $input.id}
}
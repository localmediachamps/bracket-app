query "brackets/tournament/{id}/my-bracket" verb=GET {
  api_group = "Brackets"
  description = "Get or create the current user's bracket for a tournament."
  auth = "user"

  input {
    int id {
      description = "Tournament ID"
    }
  }

  stack {
    db.get tournament {
      field_name  = "id"
      field_value = $input.id
    } as $tournament

    precondition ($tournament != null) {
      error_type = "notfound"
      error      = "Tournament not found."
    }

    db.query user_bracket {
      where  = $db.user_bracket.user_id == $auth.id && $db.user_bracket.tournament_id == $input.id
      return = {type: "single"}
    } as $existing_bracket

    var $result_bracket {
      value = null
    }

    conditional {
      if ($existing_bracket == null) {
        db.add user_bracket {
          data = {
            created_at   : now
            user_id      : $auth.id
            tournament_id: $input.id
            total_points : 0
            is_submitted : false
          }
        } as $new_bracket

        var.update $result_bracket {
          value = $new_bracket
        }
      }
      else {
        var.update $result_bracket {
          value = $existing_bracket
        }
      }
    }
  }

  response = $result_bracket
}

query "admin/match/{id}/result" verb=PUT {
  api_group = "Admin"
  description = "Record the result of a bracket match. Admin only."
  auth = "user"

  input {
    int id {
      description = "Bracket match ID"
    }
    int winner_wrestler_id {
      description = "ID of the winning wrestler"
    }
    text decision filters=trim {
      description = "Win decision type (dec, md, tf, fall, inj_def, ff, dq)"
    }
    text score? filters=trim {
      description = "Match score (optional)"
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin_check

    db.get bracket_match {
      field_name  = "id"
      field_value = $input.id
    } as $match

    precondition ($match != null) {
      error_type = "notfound"
      error      = "Bracket match not found."
    }

    db.edit bracket_match {
      field_name  = "id"
      field_value = $input.id
      data        = {
        actual_winner_wrestler_id: $input.winner_wrestler_id
        actual_winner_decision   : $input.decision
        actual_score             : $input.score
        match_status             : "complete"
      }
    } as $updated
  }

  response = $updated
}

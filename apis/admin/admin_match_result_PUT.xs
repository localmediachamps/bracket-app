// Record the result of a bracket match. Admin only.
query "admin/match/{id}/result" verb=PUT {
  api_group = "admin"
  auth = "user"

  input {
    // Bracket match ID
    int id
  
    // ID of the winning wrestler
    int winner_wrestler_id
  
    // Win decision type (dec, md, tf, fall, inj_def, ff, dq)
    text decision filters=trim
  
    // Match score (optional)
    text score? filters=trim
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin_check
  
    db.get bracket_match {
      field_name = "id"
      field_value = $input.id
    } as $match
  
    precondition ($match == null) {
      error_type = "notfound"
      error = "Bracket match not found."
    }
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $input.id
      data = {
        actual_winner_wrestler_id: $input.winner_wrestler_id
        actual_winner_decision   : $input.decision
        actual_score             : $input.score
        match_status             : "complete"
      }
    } as $updated
  }

  response = $updated
}
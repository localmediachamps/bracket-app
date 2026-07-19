// Clear a match result (ARCHITECTURE.md sections 2 and 6: DELETE /admin/matches/{id}/result).
// Delegates to apply_match_result with clear=true — unwinds downstream participants
// (unless already complete), appends a match_result_history "cleared" row, and audits.
// Conflict preconditions bubble up as 409s. Afterwards the tournament is rescored inline.
query "admin/matches/{id}/result" verb=DELETE {
  api_group = "admin"
  auth = "user"

  input {
    // Bracket match ID
    int id
  
    // Why the result is being cleared (recorded in history + audit)
    text reason filters=trim|min:1
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get bracket_match {
      field_name = "id"
      field_value = $input.id
    } as $match
  
    precondition ($match != null) {
      error_type = "notfound"
      error = "Bracket match not found."
    }
  
    function.run apply_match_result {
      input = {
        bracket_match_id: $input.id
        actor_id        : $auth.id
        clear           : true
        change_reason   : $input.reason
      }
    } as $match_result
  
    // Inline rescore of the whole tournament (MVP scale)
    function.run rescore_tournament {
      input = {tournament_id: $match.tournament_id}
    } as $rescore_summary
  }

  response = {match: $match_result, cleared: true, rescored: true}
}
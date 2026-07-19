// Full idempotent rescore + re-rank for a tournament (ARCHITECTURE.md sections 5 and 6:
// POST /admin/tournaments/{id}/rescore). Returns the rescore summary.
query "admin/tournaments/{id}/rescore" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    function.run rescore_tournament {
      input = {tournament_id: $input.id}
    } as $summary
  }

  response = $summary
}
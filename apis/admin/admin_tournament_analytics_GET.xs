// Tournament analytics for the admin dashboard (ARCHITECTURE.md sections 6 and 9:
// GET /admin/tournaments/{id}/analytics). Delegates to tournament_analytics.
query "admin/tournaments/{id}/analytics" verb=GET {
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
  
    function.run tournament_analytics {
      input = {tournament_id: $input.id}
    } as $analytics
  }

  response = $analytics
}
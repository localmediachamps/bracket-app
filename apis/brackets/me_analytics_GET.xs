// Player analytics for the current user (delegates to the player_analytics
// function).
query "me/analytics" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
  }

  stack {
    precondition ($auth[""] != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    function.run player_analytics {
      input = {user_id: $auth.id}
    } as $analytics
  }

  response = $analytics
}
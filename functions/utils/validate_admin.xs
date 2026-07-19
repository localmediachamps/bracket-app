// Validates that the authenticated user has admin privileges.
// Call this at the top of every admin API endpoint.
// Preloads and returns the full user row so callers can reuse it without an extra query.
// Require an admin user; returns the preloaded user row
function validate_admin {
  input {
    // Authenticated user id ($auth.id)
    int user_id
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $input.user_id
    } as $user
  
    precondition ($user != null && $user.is_admin) {
      error_type = "accessdenied"
      error = "Admin access required."
    }
  }

  response = $user
}
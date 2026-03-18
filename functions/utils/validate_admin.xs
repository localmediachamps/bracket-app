// Validates that the authenticated user has admin privileges
// Call this at the top of every admin API endpoint
function validate_admin {
  input {
    int user_id
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $input.user_id
      output = ["id", "is_admin"]
    } as $user
  
    precondition ($user == null || $user.is_admin != true) {
      error_type = "accessdenied"
      error = "Admin access required."
    }
  }

  response = true
}
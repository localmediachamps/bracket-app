// Get the user record belonging to the authentication token
query "auth/me" verb=GET {
  api_group = "Authentication"
  auth = "user"

  input {
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $user
  
    precondition ($user != null) {
      error_type = "notfound"
      error = "User not found."
    }
  
    var $user_out {
      value = $user|unset:"password"
    }
  }

  response = $user_out
}
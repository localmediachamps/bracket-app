// Login and retrieve an authentication token plus the user object
query "auth/login" verb=POST {
  api_group = "Authentication"

  input {
    email email? filters=trim|lower
    text password? {
      sensitive = true
    }
  }

  stack {
    db.get user {
      field_name = "email"
      field_value = $input.email
    } as $user
  
    precondition ($user != null) {
      error_type = "accessdenied"
      error = "Invalid Credentials."
    }
  
    security.check_password {
      text_password = $input.password
      hash_password = $user.password
    } as $pass_result
  
    precondition ($pass_result) {
      error_type = "accessdenied"
      error = "Invalid Credentials."
    }
  
    security.create_auth_token {
      table = "user"
      extras = {}
      expiration = 86400
      id = $user.id
    } as $authToken
  
    var $user_out {
      value = $user|unset:"password"
    }
  }

  response = {authToken: $authToken, user: $user_out}
}
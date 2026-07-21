// Consumes a password-reset token from auth/forgot-password. Single-use -
// the token is cleared on success so the same link can't be replayed.
query "auth/reset-password" verb=POST {
  api_group = "Authentication"

  input {
    text token filters=trim|min:1
    password password filters=min:8|minAlpha:1|minDigit:1 {
      sensitive = true
    }
  }

  stack {
    db.get user {
      field_name = "password_reset_token"
      field_value = $input.token
    } as $user

    precondition ($user != null) {
      error_type = "notfound"
      error = "This reset link is invalid or has already been used."
    }

    precondition ($user.password_reset_expires_at >= now) {
      error_type = "inputerror"
      error = "This reset link has expired. Request a new one."
    }

    db.edit user {
      field_name = "id"
      field_value = $user.id
      data = {
        password: $input.password
        password_reset_token: null
        password_reset_expires_at: null
        updated_at: now
      }
    } as $updated_user

    security.create_auth_token {
      table = "user"
      extras = {}
      expiration = 86400
      id = $updated_user.id
    } as $authToken

    var $user_out {
      value = $updated_user|unset:"password"|unset:"email_verify_token"|unset:"password_reset_token"
    }
  }

  response = { authToken: $authToken, user: $user_out }
  guid = "H1HsWLQXsF2kIC182KdZ0hhcgxA"
}

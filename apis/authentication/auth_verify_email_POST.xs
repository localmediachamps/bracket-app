// Confirms a signup verification link. Being unverified doesn't block
// login/play today - this just flips the flag for whatever the frontend
// chooses to gate on it later.
query "auth/verify-email" verb=POST {
  api_group = "Authentication"

  input {
    text token filters=trim|min:1
  }

  stack {
    db.get user {
      field_name = "email_verify_token"
      field_value = $input.token
    } as $user

    precondition ($user != null) {
      error_type = "notfound"
      error = "This verification link is invalid or has already been used."
    }

    precondition ($user.email_verify_expires_at >= now) {
      error_type = "inputerror"
      error = "This verification link has expired. Request a new one from your profile."
    }

    db.edit user {
      field_name = "id"
      field_value = $user.id
      data = {
        email_verified: true
        email_verify_token: null
        email_verify_expires_at: null
        updated_at: now
      }
    } as $updated_user
  }

  response = { verified: true }
  guid = "KLbRbix2EV6d1eUQv8gXSYlwozk"
}

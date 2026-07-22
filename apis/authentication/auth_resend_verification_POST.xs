// Self-serve resend of the signup verification email - auth_verify_email's
// own error message already promises "request a new one from your profile",
// but that endpoint never existed until now. No-ops with a friendly response
// if already verified rather than erroring.
query "auth/resend-verification" verb=POST {
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
      error = "Account not found."
    }

    var $already_verified {
      value = ($user.email_verified == true)
    }

    conditional {
      if ($already_verified == false) {
        security.create_uuid as $verify_token

        db.edit user {
          field_name = "id"
          field_value = $user.id
          data = {
            email_verify_token: $verify_token
            email_verify_expires_at: now|add_secs_to_timestamp:86400
            updated_at: now
          }
        } as $updated_user

        try_catch {
          try {
            function.run send_transactional_email {
              input = {
                to: $user.email
                subject: "Confirm your Mat Savvy email"
                heading: "Confirm your email"
                body_html: "<p>Click below to confirm your email address for your Mat Savvy account.</p>"
                cta_label: "Confirm email"
                cta_url: $env.frontend_url ~ "/verify-email?token=" ~ $verify_token
              }
            } as $email_send_result
          }

          catch {
            debug.log { value = "resend verification email failed: " ~ $error.message }
          }
        }
      }
    }
  }

  response = {
    sent            : ($already_verified == false)
    already_verified: $already_verified
  }
  guid = "N9kXf3RtQvBz5wYcLp2SoEjHm7Ud"
}

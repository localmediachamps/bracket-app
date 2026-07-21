// Always responds with the same generic message regardless of whether the
// email exists, so this endpoint can't be used to enumerate registered
// accounts. Reset token is short-lived (1h) and single-use.
query "auth/forgot-password" verb=POST {
  api_group = "Authentication"

  input {
    email email filters=trim|lower
  }

  stack {
    db.get user {
      field_name = "email"
      field_value = $input.email
    } as $user

    conditional {
      if ($user != null) {
        security.create_uuid as $reset_token

        db.edit user {
          field_name = "id"
          field_value = $user.id
          data = {
            password_reset_token: $reset_token
            password_reset_expires_at: now|add_secs_to_timestamp:3600
            updated_at: now
          }
        } as $updated_user

        try_catch {
          try {
            function.run send_transactional_email {
              input = {
                to: $user.email
                subject: "Reset your Mat Savvy password"
                heading: "Reset your password"
                body_html: "<p>We got a request to reset your Mat Savvy password. This link expires in 1 hour. If you didn't request this, you can safely ignore this email.</p>"
                cta_label: "Reset password"
                cta_url: $env.frontend_url ~ "/reset-password?token=" ~ $reset_token
              }
            } as $email_send_result
          }
          catch {
            debug.log { value = "password reset email failed: " ~ $error.message }
          }
        }
      }
    }
  }

  response = { message: "If an account exists for that email, a reset link is on its way." }
  guid = "ybfzRZig3IdfauXzHoid2hbpCbI"
}

// Signup: validate unique email/username, derive username from email prefix when
// blank (slugify + digit suffix until unique), create user, return auth token + user.
query "auth/signup" verb=POST {
  api_group = "Authentication"

  input {
    // Display name for the new account
    text name filters=trim|min:1
  
    // Optional handle; derived from the email prefix when blank
    text? username? filters=trim|lower
  
    // Account email (unique)
    email email filters=trim|lower
  
    // Account password
    text password filters=min:8 {
      sensitive = true
    }
  }

  stack {
    db.get user {
      field_name = "email"
      field_value = $input.email
    } as $existing_email
  
    precondition ($existing_email == null) {
      error_type = "inputerror"
      error = "This email is already in use."
    }
  
    // Resolve the username: provided value, or slugified email prefix
    var $username {
      value = $input.username
    }
  
    conditional {
      if ($username == null || ($username|strlen) == 0) {
        var $email_prefix {
          value = $input.email|split:"@"|first
        }
      
        function.run slugify {
          input = {text: $email_prefix}
        } as $slug
      
        var.update $username {
          value = $slug
        }
      
        conditional {
          if ($username == null || ($username|strlen) == 0) {
            var.update $username {
              value = "user"
            }
          }
        }
      }
    }
  
    // Ensure the username is unique by appending digits
    db.has user {
      field_name = "username"
      field_value = $username
    } as $username_taken
  
    var $suffix {
      value = 1
    }
  
    var $final_username {
      value = $username
    }
  
    while ($username_taken) {
      each {
        var.update $final_username {
          value = $username ~ $suffix
        }
      
        math.add $suffix {
          value = 1
        }
      
        db.has user {
          field_name = "username"
          field_value = $final_username
        } as $still_taken
      
        var.update $username_taken {
          value = $still_taken
        }
      }
    }
  
    security.create_uuid as $verify_token

    db.add user {
      data = {
        created_at  : now
        name        : $input.name
        email       : $input.email
        password    : $input.password
        username    : $final_username
        display_name: $input.name
        updated_at  : now
        email_verified: false
        email_verify_token: $verify_token
        email_verify_expires_at: now|add_secs_to_timestamp:86400
      }
    } as $new_user

    security.create_auth_token {
      table = "user"
      extras = {}
      expiration = 86400
      id = $new_user.id
    } as $authToken

    // Best-effort - a delivery hiccup here should never block account
    // creation. Failure is swallowed (logged) rather than surfaced to the
    // new user as a signup error.
    try_catch {
      try {
        function.run send_transactional_email {
          input = {
            to: $new_user.email
            subject: "Confirm your Mat Savvy email"
            heading: "Welcome to Mat Savvy, " ~ $new_user.name ~ "!"
            body_html: "<p>Confirm your email address to finish setting up your account.</p>"
            cta_label: "Confirm email"
            cta_url: $env.frontend_url ~ "/verify-email?token=" ~ $verify_token
          }
        } as $email_send_result
      }
      catch {
        debug.log { value = "signup verification email failed: " ~ $error.message }
      }
    }

    var $user_out {
      value = $new_user|unset:"password"|unset:"email_verify_token"|unset:"password_reset_token"
    }
  }

  response = {authToken: $authToken, user: $user_out}
  guid = "HBg59KTiQujdKxwQidN2DYOd188"
}
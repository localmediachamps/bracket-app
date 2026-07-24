// Blocks message-board post creation for a muted user - called at the top
// of both board-post-create endpoints (league + master), same pattern as
// validate_admin.xs. Deliberately narrow: this ONLY gates creating a new
// board_post, nothing else in the app checks this. board_muted_permanently
// always wins over board_muted_until (a permanent mute is never expected to
// have a future until date, but checking permanently first means it doesn't
// matter either way).
function validate_not_muted {
  input {
    // Authenticated user id ($auth.id)
    int user_id
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $input.user_id
    } as $user

    precondition ($user != null) {
      error_type = "notfound"
      error = "User not found."
    }

    var $now {
      value = now
    }

    var $is_muted {
      value = false
    }

    var $mute_message {
      value = ""
    }

    conditional {
      if ($user.board_muted_permanently == true) {
        var.update $is_muted {
          value = true
        }

        var.update $mute_message {
          value = "Your message board posting privileges have been permanently revoked."
        }
      }
      elseif ($user.board_muted_until != null && $user.board_muted_until > $now) {
        var.update $is_muted {
          value = true
        }

        var $days_remaining {
          value = (($user.board_muted_until - $now) / 86400000)|ceil
        }

        var.update $mute_message {
          value = "You're temporarily muted from posting to message boards for another " ~ ($days_remaining|to_text) ~ " day" ~ ($days_remaining == 1 ? "" : "s") ~ ". Check your notifications for details."
        }
      }
    }

    precondition ($is_muted == false) {
      error_type = "accessdenied"
      error = $mute_message
    }
  }

  response = $user
  guid = "Nz0qFA6UtBv2WhCrGi8PlAo5JsEd3"
}

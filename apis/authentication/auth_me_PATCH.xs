// Update the current user's profile fields (username must stay unique)
query "auth/me" verb=PATCH {
  api_group = "Authentication"
  auth = "user"

  input {
    // Real name
    text? name? filters=trim
  
    // Handle (unique across users)
    text? username? filters=trim|lower
  
    // Public display name
    text? display_name? filters=trim
  
    // Avatar image URL
    text? avatar_url? filters=trim
  
    // Public bio
    text? bio?
  
    // Favorite school
    text? favorite_school? filters=trim
  
    // Show up on public tournament-wide leaderboards at all
    bool? leaderboard_visible?
  
    // Which name to show when visible: display_name or username
    text? leaderboard_name_mode? filters=trim|lower
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $me
  
    precondition ($me != null) {
      error_type = "notfound"
      error = "User not found."
    }
  
    // Username must remain unique across users
    conditional {
      if ($input.username != null && $input.username != $me.username) {
        db.query user {
          where = $db.user.username == $input.username && $db.user.id != $auth.id
          return = {type: "exists"}
        } as $username_taken
      
        precondition ($username_taken == false) {
          error_type = "inputerror"
          error = "This username is already taken."
        }
      }
    }
  
    var $payload {
      value = {updated_at: now}
    }
  
    conditional {
      if ($input.name != null) {
        var.update $payload {
          value = $payload|set:"name":$input.name
        }
      }
    }
  
    conditional {
      if ($input.username != null) {
        var.update $payload {
          value = $payload|set:"username":$input.username
        }
      }
    }
  
    conditional {
      if ($input.display_name != null) {
        var.update $payload {
          value = $payload
            |set:"display_name":$input.display_name
        }
      }
    }
  
    conditional {
      if ($input.avatar_url != null) {
        var.update $payload {
          value = $payload
            |set:"avatar_url":$input.avatar_url
        }
      }
    }
  
    conditional {
      if ($input.bio != null) {
        var.update $payload {
          value = $payload|set:"bio":$input.bio
        }
      }
    }
  
    conditional {
      if ($input.favorite_school != null) {
        var.update $payload {
          value = $payload
            |set:"favorite_school":$input.favorite_school
        }
      }
    }
  
    conditional {
      if ($input.leaderboard_visible != null) {
        var.update $payload {
          value = $payload
            |set:"leaderboard_visible":$input.leaderboard_visible
        }
      }
    }
  
    conditional {
      if ($input.leaderboard_name_mode != null) {
        precondition ($input.leaderboard_name_mode == "display_name" || $input.leaderboard_name_mode == "username") {
          error_type = "inputerror"
          error = "leaderboard_name_mode must be display_name or username."
        }
      
        var.update $payload {
          value = $payload
            |set:"leaderboard_name_mode":$input.leaderboard_name_mode
        }
      }
    }
  
    db.patch user {
      field_name = "id"
      field_value = $auth.id
      data = $payload
    } as $updated_user
  
    var $user_out {
      value = $updated_user|unset:"password"
    }
  }

  response = $user_out
}
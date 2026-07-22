// Dedicated partial-field update for canonical_wrestler.profile_url. Keyed
// by the real int wrestler_id (not name - unlike teams, wrestler display
// names are NOT unique, so name-based matching would risk writing a bio
// link onto the wrong person). A genuine partial db.edit - doesn't touch
// any other field.
query "admin/canonical/wrestlers/set-profile-url" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    object[1:1000] wrestlers {
      schema {
        int wrestler_id
        text profile_url filters=trim
      }
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $updated_count { value = 0 }
    var $errors { value = [] }

    foreach ($input.wrestlers) {
      each as $w {
        try_catch {
          try {
            db.edit canonical_wrestler {
              field_name = "id"
              field_value = $w.wrestler_id
              data = {profile_url: $w.profile_url}
            } as $updated

            math.add $updated_count { value = 1 }
          }
          catch {
            array.push $errors { value = {wrestler_id: $w.wrestler_id, message: $error.message} }
          }
        }
      }
    }
  }

  response = {
    updated_count: $updated_count
    error_count  : $errors|count
    errors       : $errors
  }
  guid = "Bt3vXqWs6RwFzYmKbLo9DjP2uCe"
}

// Dedicated partial-field update for canonical_team.logo_url - same
// convention as set-roster-url/set-schedule-url (looked up by name, edited
// by id, never touches any other field).
query "admin/canonical/teams/set-logo-url" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    object[1:200] teams {
      schema {
        text name filters=trim
        text logo_url filters=trim
      }
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $updated_count { value = 0 }
    var $errors { value = [] }

    foreach ($input.teams) {
      each as $t {
        try_catch {
          try {
            db.query canonical_team {
              where = $db.canonical_team.name == $t.name
              return = {type: "single"}
            } as $existing

            conditional {
              if ($existing != null) {
                db.edit canonical_team {
                  field_name = "id"
                  field_value = $existing.id
                  data = {logo_url: $t.logo_url}
                } as $updated

                math.add $updated_count { value = 1 }
              }
              else {
                array.push $errors { value = {name: $t.name, message: "team not found"} }
              }
            }
          }
          catch {
            array.push $errors { value = {name: $t.name, message: $error.message} }
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
  guid = "Bt4vNqXs8RwLmZoKcJf3EiA6dGe"
}

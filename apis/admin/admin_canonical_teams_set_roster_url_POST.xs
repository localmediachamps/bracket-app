// Dedicated partial-field update for canonical_team.roster_url - separate
// from admin_canonical_teams_bulk_add_POST.xs (whose data map only ever
// sets `name`) so setting roster_url can never accidentally null out an
// existing value on some future unrelated bulk-add call. Looked up by name,
// then edited by id (db.edit's field_name/field_value only supports one
// lookup key, same as db.add_or_edit) - a genuine partial update, doesn't
// touch any other field.
query "admin/canonical/teams/set-roster-url" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    object[1:200] teams {
      schema {
        text name filters=trim
        text roster_url filters=trim
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
                  data = {roster_url: $t.roster_url}
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
  guid = "Xr9wYqTs4NpVzKmLbGo7CjE2uAe"
}

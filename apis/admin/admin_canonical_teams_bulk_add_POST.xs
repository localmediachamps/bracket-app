// One-time bulk creation for canonical_team, keyed on the unique `name`
// index (safe to re-run - add_or_edit by name, and name is the only field
// being set so there's no partial-overwrite risk). Used by
// build_canonical_wrestlers.py's push step to seed canonical_team before
// canonical_wrestler rows can reference a team_id.
query "admin/canonical/teams/bulk-add" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    object[1:1000] teams {
      schema {
        text name filters=trim
      }
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $results { value = [] }
    var $errors { value = [] }

    foreach ($input.teams) {
      each as $t {
        try_catch {
          try {
            db.add_or_edit canonical_team {
              field_name = "name"
              field_value = $t.name
              data = {name: $t.name}
            } as $row

            array.push $results { value = {name: $t.name, id: $row.id} }
          }
          catch {
            array.push $errors { value = {name: $t.name, message: $error.message} }
          }
        }
      }
    }
  }

  response = {
    results    : $results
    error_count: $errors|count
    errors     : $errors
  }
  guid = "Wp9nCxRj4LqYzTvBhDo6MfK2sEa"
}

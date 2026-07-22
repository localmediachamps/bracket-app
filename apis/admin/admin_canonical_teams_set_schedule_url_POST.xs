// Dedicated partial-field update for canonical_team.schedule_url - same
// convention as admin_canonical_teams_set_roster_url_POST.xs, kept separate
// from bulk-add so it can never accidentally null out an existing value.
query "admin/canonical/teams/set-schedule-url" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    object[1:200] teams {
      schema {
        text name filters=trim
        text schedule_url filters=trim
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
                  data = {schedule_url: $t.schedule_url}
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
  guid = "Nq4wZvKt8SwEyFxMcRp1TjB6oHu"
}

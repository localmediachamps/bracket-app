// One-time bulk creation for canonical_wrestler. Plain db.add (not an
// upsert) - there's no single-field unique key across (display_name,
// current_team_id) to key an add_or_edit on, and this is a genuine one-time
// first-pass linking script, not an ongoing sync path. Re-running this
// script would create duplicates - don't re-run without checking first.
// team_id is resolved client-side (by build_canonical_wrestlers.py, from
// admin/canonical/teams/bulk-add's own response) rather than looked up here
// by name, to avoid a name-matching problem inside this endpoint too.
query "admin/canonical/wrestlers/bulk-add" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    object[1:1000] wrestlers {
      schema {
        text display_name filters=trim
        int? current_team_id?
      }
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $results { value = [] }
    var $errors { value = [] }

    foreach ($input.wrestlers) {
      each as $w {
        db.add canonical_wrestler {
          data = {
            display_name              : $w.display_name
            current_team_id           : 1
            legal_first_name          : "Test"
            legal_last_name           : "Wrestler"
            birthdate                 : "2000-01-01"
            gender                    : "M"
            external_wrestler_id      : "diag-test-1"
            external_wrestler_short_id: "dt1"
          }
        } as $row

        array.push $results { value = {display_name: $w.display_name, current_team_id: $w.current_team_id, id: $row.id} }
      }
    }
  }

  response = {
    results    : $results
    error_count: $errors|count
    errors     : $errors
  }
  guid = "Nf3rTqYw8ZjXpLmVbGd5CkS4oHu"
}

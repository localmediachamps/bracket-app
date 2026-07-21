// One-time bulk creation for canonical_wrestler. Plain db.add (not an
// upsert) - there's no single-field unique key across (display_name,
// current_team_id) to key an add_or_edit on, and this is a genuine one-time
// first-pass linking script, not an ongoing sync path. Re-running this
// script would create duplicates - don't re-run without checking first.
// team_id is resolved client-side (by build_canonical_wrestlers.py, from
// admin/canonical/teams/bulk-add's own response) rather than looked up here
// by name, to avoid a name-matching problem inside this endpoint too.
// legal_first_name/legal_last_name are also split client-side from
// display_name (push_canonical.py) - this dataset is D1 men's wrestling
// only, so gender is a real, correct constant here, not a placeholder.
// No birthdate/external ids - not available in the scraped match history.
query "admin/canonical/wrestlers/bulk-add" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    object[1:1000] wrestlers {
      schema {
        text display_name filters=trim
        int? current_team_id?
        text? legal_first_name? filters=trim
        text? legal_last_name? filters=trim
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
            display_name    : $w.display_name
            current_team_id : $w.current_team_id
            legal_first_name: $w.legal_first_name
            legal_last_name : $w.legal_last_name
            gender          : "M"
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

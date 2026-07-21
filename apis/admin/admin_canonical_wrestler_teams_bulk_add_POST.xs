// One-time bulk creation for canonical_wrestler_team (the many-to-many
// wrestler<->team join, with season_label per link - see
// tables/canonical_wrestler_team.xs). Plain db.add: each (wrestler, team,
// season) triple is only ever produced once by the local identity-resolution
// script, so there's no upsert need for this one-time load.
query "admin/canonical/wrestler-teams/bulk-add" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    object[1:1000] links {
      schema {
        int canonical_wrestler_id
        int canonical_team_id
        text season_label filters=trim
        int? match_count?
      }
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $results { value = [] }
    var $errors { value = [] }

    foreach ($input.links) {
      each as $l {
        try_catch {
          try {
            db.add canonical_wrestler_team {
              data = {
                canonical_wrestler_id: $l.canonical_wrestler_id
                canonical_team_id    : $l.canonical_team_id
                season_label          : $l.season_label
                match_count           : $l.match_count
              }
            } as $row

            array.push $results { value = {id: $row.id} }
          }
          catch {
            array.push $errors { value = {canonical_wrestler_id: $l.canonical_wrestler_id, canonical_team_id: $l.canonical_team_id, season_label: $l.season_label, message: $error.message} }
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
  guid = "Ht2vNpXq8RwFzKmYbLo5CjD3uGe"
}

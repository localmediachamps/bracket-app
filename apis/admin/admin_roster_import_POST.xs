// Bulk-imports one team's official current-season roster (scraped from the
// school's own athletics site) into canonical_wrestler /
// canonical_wrestler_team. Each entry is either an already-matched existing
// wrestler (canonical_wrestler_id provided - just refreshes current_team_id/
// current_weight_class and links the season) or a brand-new profile to
// create (true incoming freshman/transfer with no prior canonical_wrestler
// row). Upserts the canonical_wrestler_team link on its own unique index, so
// this is safe to re-run for the same team/season.
query "admin/roster/import" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    int team_id
    text season_label filters=trim

    // [{canonical_wrestler_id: int|null, display_name, current_weight_class: text|null}]
    json[] entries
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $created_count { value = 0 }
    var $updated_count { value = 0 }
    var $linked_count { value = 0 }
    var $error_count { value = 0 }

    foreach ($input.entries) {
      each as $e {
        try_catch {
          try {
            var $wrestler_id { value = null }

            conditional {
              if ($e.canonical_wrestler_id != null) {
                conditional {
                  if ($e.current_weight_class != null) {
                    db.edit canonical_wrestler {
                      field_name = "id"
                      field_value = $e.canonical_wrestler_id
                      data = {current_team_id: $input.team_id, current_weight_class: $e.current_weight_class}
                    } as $updated
                  }
                  else {
                    db.edit canonical_wrestler {
                      field_name = "id"
                      field_value = $e.canonical_wrestler_id
                      data = {current_team_id: $input.team_id}
                    } as $updated
                  }
                }

                var.update $wrestler_id { value = $e.canonical_wrestler_id }
                math.add $updated_count { value = 1 }
              }
              else {
                db.add canonical_wrestler {
                  data = {
                    display_name        : $e.display_name
                    current_team_id     : $input.team_id
                    current_weight_class: $e.current_weight_class
                  }
                } as $created

                var.update $wrestler_id { value = $created.id }
                math.add $created_count { value = 1 }
              }
            }

            db.query canonical_wrestler_team {
              where = ($db.canonical_wrestler_team.canonical_wrestler_id == $wrestler_id) && ($db.canonical_wrestler_team.canonical_team_id == $input.team_id) && ($db.canonical_wrestler_team.season_label == $input.season_label)
              return = {type: "single"}
            } as $existing_link

            conditional {
              if ($existing_link == null) {
                db.add canonical_wrestler_team {
                  data = {
                    canonical_wrestler_id: $wrestler_id
                    canonical_team_id    : $input.team_id
                    season_label         : $input.season_label
                  }
                } as $created_link

                math.add $linked_count { value = 1 }
              }
            }
          }

          catch {
            math.add $error_count { value = 1 }
          }
        }
      }
    }
  }

  response = {
    created: $created_count
    updated: $updated_count
    linked : $linked_count
    errors : $error_count
  }
  guid = "K8mFtQ3xLbNs7RyWpZoJh5VcTa9D"
}

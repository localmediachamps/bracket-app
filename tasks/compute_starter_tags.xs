// Refreshes the stored canonical_wrestler_team.is_starter flag for every
// team/season combination, via functions/utils/compute_team_starter_flags.xs.
// Runs weekly - real teams are usually consistent about who starts, so this
// doesn't need to be more frequent than that (see canonical_wrestler_team.xs
// for why this is stored rather than computed live per read).
task compute_starter_tags {
  stack {
    db.query canonical_wrestler_team {
      return = {type: "list", paging: {page: 1, per_page: 50000}}
    } as $all_rows

    var $team_seasons { value = {} }

    foreach ($all_rows.items) {
      each as $r {
        var $key { value = (($r.canonical_team_id|to_text) ~ ":" ~ $r.season_label) }

        var.update $team_seasons {
          value = $team_seasons|set:$key:{team_id: $r.canonical_team_id, season_label: $r.season_label}
        }
      }
    }

    var $keys { value = ($team_seasons|keys) }

    foreach ($keys) {
      each as $k {
        var $ts { value = $team_seasons|get:$k:null }

        conditional {
          if ($ts != null) {
            function.run compute_team_starter_flags {
              input = {team_id: $ts.team_id, season_label: $ts.season_label}
            } as $flags

            foreach ($flags) {
              each as $f {
                db.edit canonical_wrestler_team {
                  field_name = "id"
                  field_value = $f.row_id
                  data = {is_starter: $f.is_starter}
                } as $updated
              }
            }
          }
        }
      }
    }
  }

  schedule = [{starts_on: 2026-07-24 06:00:00+0000, freq: 604800}]
  guid = "T8xVn5ZkRs9McQpYo3HvJd6FgAe2"
}

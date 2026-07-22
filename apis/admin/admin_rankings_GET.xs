// Lists the composite ranking for one weight+season, ordered by rank, joined
// with wrestler display info for the admin rankings management UI.
query "admin/rankings" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    int weight
    int season_year
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.query wrestler_composite_ranking {
      where = ($db.wrestler_composite_ranking.weight == $input.weight) && ($db.wrestler_composite_ranking.season_year == $input.season_year)
      sort = {wrestler_composite_ranking.rank: "asc"}
      return = {type: "list"}
    } as $rows

    var $out {
      value = []
    }

    foreach ($rows) {
      each as $r {
        db.get canonical_wrestler {
          field_name = "id"
          field_value = $r.canonical_wrestler_id
        } as $w

        var $team_name {
          value = null
        }

        conditional {
          if ($w != null && $w.current_team_id != null) {
            db.get canonical_team {
              field_name = "id"
              field_value = $w.current_team_id
            } as $t

            conditional {
              if ($t != null) {
                var.update $team_name {
                  value = $t.name
                }
              }
            }
          }
        }

        array.push $out {
          value = {
            id                   : $r.id
            canonical_wrestler_id: $r.canonical_wrestler_id
            display_name         : $w|get:"display_name":null
            team_name            : $team_name
            rank                 : $r.rank
          }
        }
      }
    }
  }

  response = {
    rankings: $out
  }
  guid = "K7wRp2ZsQm9TnCvXo5LhBd4FeUy3"
}

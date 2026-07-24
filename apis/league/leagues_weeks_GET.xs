// The season_week timeline for a league's season, week ascending - powers
// the lineup page's week selector and the commissioner's WeeksPanel. Each
// week's week_type/linked_tournament_id/tournament_game_mode/
// placement_points_config is THIS LEAGUE's effective view - overlaying any
// league_week_override row on top of the shared season_week base, so two
// leagues in the same season can see the same week as head_to_head for one
// and marquee_tournament (linked to a different tournament, even) for the
// other. Shape is otherwise identical to a raw season_week row, so nothing
// downstream needs to know whether a value came from the override or the
// base.
query "leagues/weeks" verb=GET {
  api_group = "league"
  auth = "user"

  input {
    int league_id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get league {
      field_name = "id"
      field_value = $input.league_id
    } as $league

    precondition ($league != null) {
      error_type = "notfound"
      error = "League not found."
    }

    db.query season_week {
      where = $db.season_week.season_id == $league.season_id
      sort = {season_week.week_number: "asc"}
      return = {type: "list"}
    } as $weeks

    db.query league_week_override {
      where = $db.league_week_override.league_id == $league.id
      return = {type: "list"}
    } as $overrides

    var $effective_weeks {
      value = []
    }

    foreach ($weeks) {
      each as $w {
        var $override_match {
          value = null
        }

        foreach ($overrides) {
          each as $ov {
            conditional {
              if ($ov.season_week_id == $w.id) {
                var.update $override_match {
                  value = $ov
                }
              }
            }
          }
        }

        var $eff_week_type {
          value = $w.week_type
        }

        var $eff_linked_tournament_id {
          value = $w.linked_tournament_id
        }

        var $eff_tournament_game_mode {
          value = $w.tournament_game_mode
        }

        var $eff_placement_points_config {
          value = $w.placement_points_config
        }

        conditional {
          if ($override_match != null) {
            var.update $eff_week_type {
              value = $override_match.week_type
            }

            var.update $eff_linked_tournament_id {
              value = $override_match.linked_tournament_id
            }

            var.update $eff_tournament_game_mode {
              value = $override_match.tournament_game_mode
            }

            var.update $eff_placement_points_config {
              value = $override_match.placement_points_config
            }
          }
        }

        array.push $effective_weeks {
          value = {
            id                     : $w.id
            season_id              : $w.season_id
            week_number            : $w.week_number
            starts_at              : $w.starts_at
            ends_at                : $w.ends_at
            status                 : $w.status
            week_type              : $eff_week_type
            base_week_type         : $w.week_type
            linked_tournament_id   : $eff_linked_tournament_id
            tournament_game_mode   : $eff_tournament_game_mode
            placement_points_config: $eff_placement_points_config
          }
        }
      }
    }
  }

  response = $effective_weeks
  guid = "TMFLTuXjyneBDfQnQXOnul4vUTw"
}

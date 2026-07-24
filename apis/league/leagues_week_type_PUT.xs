// Commissioner sets THIS league's effective type for a shared season_week -
// head_to_head or marquee_tournament - independent of every other league in
// the same season and independent of season_week's own base value. Writes
// (upserts) a league_week_override row rather than touching season_week
// directly, since season_week is shared infrastructure across every league
// in the season (see tables/league_week_override.xs header). Only usable on
// weeks whose base type is head_to_head or marquee_tournament - conference/
// nationals stay universal, never overridable per-league. Switching to
// head_to_head clears any tournament link/mode/placement config this league
// had set, since those are meaningless once the week isn't marquee for them.
// Use leagues_week_config_PUT.xs afterward to pick the actual tournament +
// contest mode once a week is marquee for this league.
query "leagues/week/type" verb=PUT {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int season_week_id
    text week_type filters=trim|lower
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    precondition ($input.week_type == "head_to_head" || $input.week_type == "marquee_tournament") {
      error_type = "inputerror"
      error = "week_type must be head_to_head or marquee_tournament."
    }

    db.get league {
      field_name = "id"
      field_value = $input.league_id
    } as $league

    precondition ($league != null) {
      error_type = "notfound"
      error = "League not found."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id && $db.league_membership.status == "active" && ($db.league_membership.role == "owner" || $db.league_membership.role == "commissioner")
      return = {type: "exists"}
    } as $is_commissioner

    precondition ($is_commissioner) {
      error_type = "accessdenied"
      error = "Only the league owner or a commissioner can change a week's type."
    }

    db.get season_week {
      field_name = "id"
      field_value = $input.season_week_id
    } as $week

    precondition ($week != null && $week.season_id == $league.season_id) {
      error_type = "inputerror"
      error = "That week isn't part of this league's season."
    }

    precondition ($week.week_type == "head_to_head" || $week.week_type == "marquee_tournament") {
      error_type = "inputerror"
      error = "Conference and nationals weeks are always universal and can't be overridden per league."
    }

    precondition ($week.status == "upcoming") {
      error_type = "inputerror"
      error = "Only an upcoming week (not yet open, locked, or scored) can be changed."
    }

    db.query league_week_override {
      where = $db.league_week_override.league_id == $league.id && $db.league_week_override.season_week_id == $week.id
      return = {type: "single"}
    } as $existing_override

    // Switching to head_to_head clears any tournament link this league had
    // set (meaningless once the week isn't marquee for them). Switching to
    // marquee_tournament leaves tournament fields alone - they're either
    // already null (never configured, or previously cleared) or the
    // commissioner will set them next via leagues_week_config_PUT.xs.
    var $updated_override {
      value = null
    }

    conditional {
      if ($existing_override != null) {
        conditional {
          if ($input.week_type == "head_to_head") {
            db.edit league_week_override {
              field_name = "id"
              field_value = $existing_override.id
              data = {
                week_type              : $input.week_type
                linked_tournament_id   : null
                tournament_game_mode   : null
                placement_points_config: null
              }
            } as $edit_result_cleared

            var.update $updated_override {
              value = $edit_result_cleared
            }
          }
          else {
            db.edit league_week_override {
              field_name = "id"
              field_value = $existing_override.id
              data = {
                week_type: $input.week_type
              }
            } as $edit_result

            var.update $updated_override {
              value = $edit_result
            }
          }
        }
      }
      else {
        conditional {
          if ($input.week_type == "head_to_head") {
            db.add league_week_override {
              data = {
                league_id              : $league.id
                season_week_id         : $week.id
                week_type              : $input.week_type
                linked_tournament_id   : null
                tournament_game_mode   : null
                placement_points_config: null
              }
            } as $add_result_cleared

            var.update $updated_override {
              value = $add_result_cleared
            }
          }
          else {
            db.add league_week_override {
              data = {
                league_id     : $league.id
                season_week_id: $week.id
                week_type     : $input.week_type
              }
            } as $add_result

            var.update $updated_override {
              value = $add_result
            }
          }
        }
      }
    }
  }

  response = $updated_override
  guid = "Gr4xAn6FqVu8SkZoDb3MiPj5LlCx7"
}

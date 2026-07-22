// Commissioner configures a marquee_tournament week: which real tournament
// it's tied to, which contest mode runs (bracket / pickem / bracket_pickem),
// and the per-tournament placement->points table. Picks from existing
// tournament rows - creating the tournament itself is the normal admin
// tournament-builder flow, unchanged here. conference/nationals weeks don't
// use this endpoint at all - they're always roster-scored, no linked
// tournament or game mode to pick; their own placement-points table (if the
// commissioner wants to override the default) is set via
// leagues_week_placement_config_PUT.xs instead (see the fantasy league
// plan's postseason redesign, 2026-07-22).
query "leagues/week/config" verb=PUT {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int season_week_id
    text tournament_game_mode filters=trim|lower
    int linked_tournament_id
    json? placement_points_config?
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    precondition ($input.tournament_game_mode == "bracket" || $input.tournament_game_mode == "pickem" || $input.tournament_game_mode == "bracket_pickem") {
      error_type = "inputerror"
      error = "tournament_game_mode must be bracket, pickem, or bracket_pickem."
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
      error = "Only the league owner or a commissioner can configure a week."
    }

    db.get season_week {
      field_name = "id"
      field_value = $input.season_week_id
    } as $week

    precondition ($week != null && $week.season_id == $league.season_id) {
      error_type = "inputerror"
      error = "That week isn't part of this league's season."
    }

    precondition ($week.week_type == "marquee_tournament") {
      error_type = "inputerror"
      error = "Only marquee_tournament weeks take a commissioner-configured tournament mode."
    }

    db.get tournament {
      field_name = "id"
      field_value = $input.linked_tournament_id
    } as $tournament

    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }

    db.edit season_week {
      field_name = "id"
      field_value = $week.id
      data = {
        linked_tournament_id  : $input.linked_tournament_id
        tournament_game_mode  : $input.tournament_game_mode
        placement_points_config: $input.placement_points_config
      }
    } as $updated_week
  }

  response = $updated_week
  guid = "scs1cE917FtfdS69MacrQeIwV3A"
}

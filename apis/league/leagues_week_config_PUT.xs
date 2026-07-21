// Commissioner configures a non-head-to-head week: which real tournament it's
// tied to, and which of the 5 modes runs for it (roster / bracket / pickem /
// bracket_pickem / tournament_draft). Picks from existing tournament rows -
// creating the tournament itself is the normal admin tournament-builder flow,
// unchanged here.
query "leagues/week/config" verb=PUT {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int season_week_id
    text tournament_game_mode filters=trim|lower
    int linked_tournament_id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    precondition ($input.tournament_game_mode == "roster" || $input.tournament_game_mode == "bracket" || $input.tournament_game_mode == "pickem" || $input.tournament_game_mode == "bracket_pickem" || $input.tournament_game_mode == "tournament_draft") {
      error_type = "inputerror"
      error = "tournament_game_mode must be roster, bracket, pickem, bracket_pickem, or tournament_draft."
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

    precondition ($week.week_type != "head_to_head") {
      error_type = "inputerror"
      error = "Head-to-head weeks don't use a tournament mode."
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
        linked_tournament_id : $input.linked_tournament_id
        tournament_game_mode : $input.tournament_game_mode
      }
    } as $updated_week
  }

  response = $updated_week
  guid = "scs1cE917FtfdS69MacrQeIwV3A"
}

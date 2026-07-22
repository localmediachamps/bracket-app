// Commissioner sets a conference/nationals week's placement->points table
// (rank->points, e.g. {"1":12,"2":10,...,"default":0}) - separate from
// leagues_week_config_PUT.xs since these weeks have no linked tournament or
// game mode to configure, just the standings-points table used when the
// scoring cron ranks members by their own roster's week score (see the
// fantasy league plan's 2026-07-22 postseason redesign). Falls back to
// get_default_league_config.xs's placement_points_defaults[week_type] when
// left unset - this endpoint is how a commissioner overrides that default,
// not a requirement to set one.
query "leagues/week/placement-config" verb=PUT {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int season_week_id
    json placement_points_config
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

    precondition ($week.week_type == "conference" || $week.week_type == "nationals") {
      error_type = "inputerror"
      error = "Only conference or nationals weeks take a placement-points table through this endpoint."
    }

    db.edit season_week {
      field_name = "id"
      field_value = $week.id
      data = {placement_points_config: $input.placement_points_config}
    } as $updated_week
  }

  response = $updated_week
  guid = "Cx6vSrMj9NuBpZoTdWa3EgL2hFk"
}

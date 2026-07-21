// The season_week timeline for a league's season, week ascending - powers
// the lineup page's week selector.
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
  }

  response = $weeks
  guid = "TMFLTuXjyneBDfQnQXOnul4vUTw"
}

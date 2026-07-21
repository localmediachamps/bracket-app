// The season-level weight class catalog for a league's season, weight
// ascending - powers the draft room's weight-class selector.
query "leagues/weight-classes" verb=GET {
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

    db.query season_weight_class {
      where = $db.season_weight_class.season_id == $league.season_id
      sort = {season_weight_class.weight: "asc"}
      return = {type: "list"}
    } as $weight_classes
  }

  response = $weight_classes
  guid = "TquIPKmiMInGQeWpJAi5zY-jeyI"
}

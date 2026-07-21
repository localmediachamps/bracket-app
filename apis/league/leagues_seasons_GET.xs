// Public list of fantasy-league seasons, for the "create a league" season
// picker. Newest year first.
query "leagues/seasons" verb=GET {
  api_group = "league"

  input {
  }

  stack {
    db.query season {
      sort = {season.year: "desc"}
      return = {type: "list"}
    } as $seasons
  }

  response = $seasons
  guid = "K4XG-boXaTqVVVN-X-8UqJsGVDs"
}

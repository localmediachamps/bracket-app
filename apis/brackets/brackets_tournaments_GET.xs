// List all tournaments ordered by year descending.
query "brackets/tournaments" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
  }

  stack {
    db.query tournament {
      sort = {tournament.year: "desc"}
      return = {type: "list"}
    } as $tournaments
  }

  response = $tournaments
}
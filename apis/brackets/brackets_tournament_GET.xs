query "brackets/tournament/{id}" verb=GET {
  api_group = "Brackets"
  description = "Get a tournament with its weight classes."
  auth = "user"

  input {
    int id {
      description = "Tournament ID"
    }
  }

  stack {
    db.get tournament {
      field_name  = "id"
      field_value = $input.id
    } as $tournament

    precondition ($tournament != null) {
      error_type = "notfound"
      error      = "Tournament not found."
    }

    db.query weight_class {
      where  = $db.weight_class.tournament_id == $input.id
      sort   = {weight_class.weight: "asc"}
      return = {type: "list"}
    } as $weight_classes
  }

  response = {tournament: $tournament, weight_classes: $weight_classes}
}

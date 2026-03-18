// Get all completed match results for a tournament with wrestler details.
query "brackets/tournament/{id}/results" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    // Tournament ID
    int id
  }

  stack {
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament == null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $input.id && $db.bracket_match.match_status == "complete"
      return = {type: "list"}
    } as $matches
  
    db.query wrestler {
      where = $db.wrestler.tournament_id == $input.id
      return = {type: "list"}
    } as $wrestlers
  
    var $wrestlers_map {
      value = {}
    }
  
    foreach ($wrestlers) {
      each as $w {
        var.update $wrestlers_map {
          value = $wrestlers_map|set:$w.id:$w
        }
      }
    }
  }

  response = {matches: $matches, wrestlers_map: $wrestlers_map}
}
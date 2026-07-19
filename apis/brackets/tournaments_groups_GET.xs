// Public groups for a tournament with member counts and owner summaries.
query "tournaments/{id}/groups" verb=GET {
  api_group = "brackets"

  input {
    // Tournament id
    int id
  }

  stack {
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    db.query fantasy_group {
      where = $db.fantasy_group.tournament_id == $input.id && $db.fantasy_group.privacy == "public"
      sort = {fantasy_group.created_at: "desc"}
      return = {type: "list"}
    } as $groups
  
    var $items {
      value = []
    }
  
    foreach ($groups) {
      each as $g {
        db.get user {
          field_name = "id"
          field_value = $g.owner_id
          output = ["id", "username", "display_name"]
        } as $owner
      
        array.push $items {
          value = $g|set:"owner":$owner
        }
      }
    }
  }

  response = $items
}
// Get the leaderboard for a tournament with user names and rankings.
query "brackets/tournament/{id}/leaderboard" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    // Tournament ID
    int id
  
    // Page number
    int page?=1 filters=min:1
  
    // Results per page
    int per?=25 filters=min:1|max:100
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
  
    db.query user_bracket {
      where = $db.user_bracket.tournament_id == $input.id
      sort = {user_bracket.total_points: "desc"}
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $brackets_page
  
    var $enriched_items {
      value = []
    }
  
    foreach ($brackets_page.items) {
      each as $bracket {
        db.get user {
          field_name = "id"
          field_value = $bracket.user_id
          output = ["id", "name"]
        } as $bracket_user
      
        var $item {
          value = $bracket
            |set:"user_name":$bracket_user.name
        }
      
        array.push $enriched_items {
          value = $item
        }
      }
    }
  }

  response = {
    items    : $enriched_items
    curPage  : $brackets_page.curPage
    pageTotal: $brackets_page.pageTotal
  }
}
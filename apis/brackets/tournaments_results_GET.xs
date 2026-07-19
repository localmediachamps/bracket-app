// Completed match results for a tournament, newest first, with weight class and
// winner/loser wrestler summaries.
query "tournaments/{id}/results" verb=GET {
  api_group = "brackets"

  input {
    // Tournament id
    int id
  
    // Optional weight class filter
    int? weight_class_id?
  
    int page?=1 filters=min:1
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
  
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $input.id && ($db.bracket_match.match_status == "complete" || $db.bracket_match.match_status == "corrected") && $db.bracket_match.weight_class_id ==? $input.weight_class_id
      sort = {bracket_match.completed_at: "desc"}
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $page
  
    var $items {
      value = []
    }
  
    foreach ($page.items) {
      each as $m {
        db.get weight_class {
          field_name = "id"
          field_value = $m.weight_class_id
          output = ["id", "weight", "name"]
        } as $wc
      
        var $winner {
          value = null
        }
      
        conditional {
          if ($m.actual_winner_wrestler_id != null) {
            db.get wrestler {
              field_name = "id"
              field_value = $m.actual_winner_wrestler_id
              output = ["id", "name", "school", "seed"]
            } as $winner_row
          
            var.update $winner {
              value = $winner_row
            }
          }
        }
      
        var $loser {
          value = null
        }
      
        conditional {
          if ($m.actual_loser_wrestler_id != null) {
            db.get wrestler {
              field_name = "id"
              field_value = $m.actual_loser_wrestler_id
              output = ["id", "name", "school", "seed"]
            } as $loser_row
          
            var.update $loser {
              value = $loser_row
            }
          }
        }
      
        array.push $items {
          value = $m
            |set:"weight":$wc.weight
            |set:"weight_class_name":$wc.name
            |set:"winner":$winner
            |set:"loser":$loser
        }
      }
    }
  }

  response = {
    items: $items
    total: $page.itemsTotal
    page : $input.page
    per  : $input.per
  }
}
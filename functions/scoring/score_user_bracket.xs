// Scores all picks for a single user_bracket.
// Compares each pick against actual match results and awards points per round.
// Returns the total points earned.
function score_user_bracket {
  input {
    int user_bracket_id
    int tournament_id
  }

  stack {
    // Get all scoring rules for this tournament
    db.query scoring_rule {
      where = {} == true
      return = {type: "list"}
      output = ["round_code", "points"]
    } as $rules
  
    // Build round_code -> points lookup map
    var $points_map {
      value = {}
    }
  
    foreach ($rules) {
      each as $r {
        var.update $points_map {
          value = $points_map|set:$r.round_code:$r.points
        }
      }
    }
  
    // Get all picks for this user bracket
    db.query user_pick {
      where = {} == true
      return = {type: "list"}
      output = ["id", "bracket_match_id", "picked_wrestler_id"]
    } as $picks
  
    var $total_points {
      value = 0
    }
  
    foreach ($picks) {
      each as $pick {
        db.get bracket_match {
          field_name = "id"
          field_value = $pick.bracket_match_id
          output = ["id", "round_code", "actual_winner_wrestler_id", "match_status"]
        } as $match
      
        var $is_correct {
          value = false
        }
      
        var $points_earned {
          value = 0
        }
      
        conditional {
          if ($match.match_status == "complete" && $match.actual_winner_wrestler_id != null) {
            conditional {
              if ($pick.picked_wrestler_id == $match.actual_winner_wrestler_id) {
                var.update $is_correct {
                  value = true
                }
              
                var $round_points {
                  value = $points_map[$match.round_code]
                }
              
                conditional {
                  if ($round_points != null) {
                    var.update $points_earned {
                      value = $round_points
                    }
                  
                    math.add $total_points {
                      value = $round_points
                    }
                  }
                }
              }
            }
          }
        }
      
        db.edit user_pick {
          field_name = "id"
          field_value = $pick.id
          data = {is_correct: $is_correct, points_earned: $points_earned}
        } as $updated_pick
      }
    }
  
    // Update the user_bracket total
    db.edit user_bracket {
      field_name = "id"
      field_value = $input.user_bracket_id
      data = {total_points: $total_points}
    } as $updated_bracket
  }

  response = {
    user_bracket_id: $input.user_bracket_id
    total_points   : $total_points
  }
}
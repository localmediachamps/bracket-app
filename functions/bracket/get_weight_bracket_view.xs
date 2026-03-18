// Returns all bracket_match rows for a weight class merged with a user's picks.
// Used by the bracket picker frontend to render the full bracket state.
function get_weight_bracket_view {
  input {
    int weight_class_id
    int tournament_id
  
    // optional - if provided, merges user picks into the response
    int user_bracket_id?
  }

  stack {
    // Get all matches for this weight class
    db.query bracket_match {
      where = {} == true
      return = {type: "list"}
      output = [
        "id"
        "round_code"
        "match_number"
        "bracket_side"
        "winner_advances_to_match_id"
        "loser_drops_to_match_id"
        "winner_slot_in_next"
        "loser_slot_in_next"
        "actual_top_wrestler_id"
        "actual_bottom_wrestler_id"
        "actual_winner_wrestler_id"
        "actual_winner_decision"
        "actual_score"
        "match_status"
      ]
    } as $matches
  
    // Get all wrestlers for this weight class
    db.query wrestler {
      where = {} == true
      return = {type: "list"}
      output = ["id", "seed", "name", "school", "record"]
    } as $wrestlers
  
    // Build wrestler lookup by id
    var $wrestler_map {
      value = {}
    }
  
    foreach ($wrestlers) {
      each as $w {
        var.update $wrestler_map {
          value = $wrestler_map|set:$w.id:$w
        }
      }
    }
  
    // Get user picks if user_bracket_id provided
    var $pick_map {
      value = {}
    }
  
    conditional {
      if ($input.user_bracket_id != null) {
        db.query user_pick {
          where = {} == true
          return = {type: "list"}
          output = [
            "id"
            "bracket_match_id"
            "picked_wrestler_id"
            "is_correct"
            "points_earned"
          ]
        } as $picks
      
        foreach ($picks) {
          each as $p {
            var.update $pick_map {
              value = $pick_map|set:$p.bracket_match_id:$p
            }
          }
        }
      }
    }
  
    // Enrich each match with wrestler names and user picks
    var $enriched_matches {
      value = []
    }
  
    foreach ($matches) {
      each as $m {
        var $top_wrestler {
          value = $wrestler_map[$m.actual_top_wrestler_id]
        }
      
        var $bottom_wrestler {
          value = $wrestler_map[$m.actual_bottom_wrestler_id]
        }
      
        var $winner_wrestler {
          value = $wrestler_map[$m.actual_winner_wrestler_id]
        }
      
        var $user_pick_data {
          value = $pick_map[$m.id]
        }
      
        array.push $enriched_matches {
          value = {
            id                         : $m.id
            round_code                 : $m.round_code
            match_number               : $m.match_number
            bracket_side               : $m.bracket_side
            winner_advances_to_match_id: $m.winner_advances_to_match_id
            loser_drops_to_match_id    : $m.loser_drops_to_match_id
            winner_slot_in_next        : $m.winner_slot_in_next
            loser_slot_in_next         : $m.loser_slot_in_next
            top_wrestler               : $top_wrestler
            bottom_wrestler            : $bottom_wrestler
            actual_winner              : $winner_wrestler
            actual_winner_decision     : $m.actual_winner_decision
            actual_score               : $m.actual_score
            match_status               : $m.match_status
            user_pick                  : $user_pick_data
          }
        }
      }
    }
  }

  response = {
    weight_class_id: $input.weight_class_id
    wrestlers      : $wrestlers
    matches        : $enriched_matches
  }
}
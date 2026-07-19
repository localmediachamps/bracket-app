// Progress helper for progress bars on entries and tournament pages.
// total_matches = non-bye matches tournament-wide (byes are displayed, not predicted).
// picked = pick count on the given entry (0 when no entry id is passed).
// complete_count = non-bye matches with a final result (complete or corrected).
// Return {total_matches, picked, complete_count} for a tournament and optional entry
function tournament_progress {
  input {
    // Tournament to measure
    int tournament_id
  
    // Optional entry id; when given, picked = that entry's pick count
    int? user_bracket_id?
  }

  stack {
    // All non-bye matches in the tournament
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $input.tournament_id && $db.bracket_match.is_bye == false
      return = {type: "count"}
    } as $total_matches
  
    // Non-bye matches with a final result
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $input.tournament_id && $db.bracket_match.is_bye == false && ($db.bracket_match.match_status == "complete" || $db.bracket_match.match_status == "corrected")
      return = {type: "count"}
    } as $complete_count
  
    var $picked {
      value = 0
    }
  
    conditional {
      if ($input.user_bracket_id != null) {
        db.query user_pick {
          where = $db.user_pick.user_bracket_id == $input.user_bracket_id
          return = {type: "count"}
        } as $pick_count
      
        var.update $picked {
          value = $pick_count
        }
      }
    }
  }

  response = {
    total_matches : $total_matches
    picked        : $picked
    complete_count: $complete_count
  }
}
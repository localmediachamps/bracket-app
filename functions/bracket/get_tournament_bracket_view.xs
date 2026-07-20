// Full bracket view for one weight class (the money endpoint's actual logic).
// Moved out of tournaments/{id}/bracket/{weightClassId} entirely — that query
// object's own db.*/function.run bindings kept corrupting after repeated
// edits (confirmed via elimination: identical statements work fine inside a
// function, 403 inside that query). Functions have proven reliable all
// session, so the query is now a thin single-call wrapper around this.
// entry_id is honored only for the entry owner; pick percentages are
// computed only once the tournament is locked/live/completed or revealed.
function get_tournament_bracket_view {
  input {
    // Tournament id
    int tournament_id
  
    // Weight class id
    int weight_class_id
  
    // Optional entry whose picks should be merged into the view
    int? entry_id?
  
    // Request pick percentages (gated by tournament status / reveal flag)
    bool? pick_percentages?
  
    // Requesting user's id (null when unauthenticated)
    int? auth_user_id?
  }

  stack {
    db.get tournament {
      field_name = "id"
      field_value = $input.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    db.get weight_class {
      field_name = "id"
      field_value = $input.weight_class_id
    } as $weight_class
  
    precondition ($weight_class != null && $weight_class.tournament_id == $input.tournament_id) {
      error_type = "notfound"
      error = "Weight class not found for this tournament."
    }
  
    // entry_id requires authentication plus ownership
    var $verified_entry_id {
      value = null
    }
  
    conditional {
      if ($input.entry_id != null) {
        precondition ($input.auth_user_id != null) {
          error_type = "unauthorized"
          error = "Authentication is required to view entry picks."
        }
      
        function.run verify_entry_ownership {
          input = {
            entry_id     : $input.entry_id
            tournament_id: $input.tournament_id
            user_id      : $input.auth_user_id
          }
        } as $verified_entry
      
        var.update $verified_entry_id {
          value = $verified_entry.id
        }
      }
    }
  
    // Pick percentages gated to locked/live/completed or the explicit reveal flag
    var $include_percentages {
      value = false
    }
  
    conditional {
      if ($input.pick_percentages && ($tournament.status == "locked" || $tournament.status == "live" || $tournament.status == "completed" || $tournament.show_pick_percentages)) {
        var.update $include_percentages {
          value = true
        }
      }
    }
  
    function.run get_weight_bracket_view {
      input = {
        weight_class_id : $input.weight_class_id
        tournament_id   : $input.tournament_id
        entry_id        : $verified_entry_id
        pick_percentages: $include_percentages
      }
    } as $view
  }

  response = $view
  guid = "4_2915AdaUoVUZoq32wqa0YrBe8"
}
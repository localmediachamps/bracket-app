// Full bracket view for one weight class (the money endpoint).
// entry_id is honored only for the entry owner (or admin); pick percentages are
// computed only once the tournament is locked/live/completed or explicitly revealed.
query "tournaments/{id}/bracket/{weightClassId}" verb=GET {
  api_group = "brackets"

  input {
    // Tournament id
    int id
  
    // Weight class id
    int weightClassId
  
    // Optional entry whose picks should be merged into the view
    int? entry_id?
  
    // Request pick percentages (gated by tournament status / reveal flag)
    bool? pick_percentages?
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
  
    db.get weight_class {
      field_name = "id"
      field_value = $input.weightClassId
    } as $weight_class
  
    precondition ($weight_class != null && $weight_class.tournament_id == $input.id) {
      error_type = "notfound"
      error = "Weight class not found for this tournament."
    }
  
    // entry_id requires authentication plus ownership (or admin)
    var $verified_entry_id {
      value = null
    }
  
    conditional {
      if ($input.entry_id != null) {
        precondition ($auth.id != null) {
          error_type = "unauthorized"
          error = "Authentication is required to view entry picks."
        }
      
        db.get user_bracket {
          field_name = "id"
          field_value = $input.entry_id
        } as $entry
      
        precondition ($entry != null) {
          error_type = "notfound"
          error = "Entry not found."
        }
      
        precondition ($entry.tournament_id == $input.id) {
          error_type = "inputerror"
          error = "Entry does not belong to this tournament."
        }
      
        var $entry_is_admin {
          value = false
        }
      
        conditional {
          if ($entry.user_id != $auth.id) {
            db.get user {
              field_name = "id"
              field_value = $auth.id
              output = ["id", "is_admin"]
            } as $admin_check
          
            conditional {
              if ($admin_check != null && $admin_check.is_admin) {
                var.update $entry_is_admin {
                  value = true
                }
              }
            }
          }
        }
      
        precondition ($entry.user_id == $auth.id || $entry_is_admin) {
          error_type = "accessdenied"
          error = "You do not own this entry."
        }
      
        var.update $verified_entry_id {
          value = $entry.id
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
        weight_class_id : $input.weightClassId
        tournament_id   : $input.id
        entry_id        : $verified_entry_id
        pick_percentages: $include_percentages
      }
    } as $view
  }

  response = $view
}
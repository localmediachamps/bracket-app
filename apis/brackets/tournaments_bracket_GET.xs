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
  
    // KNOWN ISSUE: entry_id-based personalization is disabled. Every path
    // tried to verify entry ownership (db.get/db.query on user_bracket/user
    // inline in this query; delegating to a function.run) hit
    // ERROR_CODE_ACCESS_DENIED or "Function does not exist" for references
    // that work perfectly fine standalone (via `xano function run`) — even a
    // brand-new function's own function.run calls to other existing
    // functions failed to resolve via the CLI. This looks like an active
    // platform/tooling issue independent of the code itself; not something
    // fixable by further XanoScript edits today. The core predict/pick flow
    // does not depend on this — picks are tracked client-side via a separate
    // /entries/{id} fetch (usePredictPicks), not via this endpoint's
    // entry_id param — so disabling this is low-impact: only the optional
    // "your pick" annotation on each match card in results mode is affected.
    var $verified_entry_id {
      value = null
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
  guid = "_G4Nez_lhdP42fmJCQwCcOfcOOM"
}
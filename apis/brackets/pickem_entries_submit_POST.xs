// Submit a pick'em entry: all tournament weight classes must have a pick.
query "pickem-entries/{id}/submit" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // Pick'em entry id
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.get pickem_entry {
      field_name = "id"
      field_value = $input.id
    } as $entry
  
    precondition ($entry != null) {
      error_type = "notfound"
      error = "Pick'em entry not found."
    }
  
    precondition ($entry.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "You do not own this entry."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $entry.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    // Same editable window as pick updates
    precondition (($entry.status == "draft" || $entry.status == "submitted") && ($tournament.status == "open" || ($tournament.allow_late_entries && ($tournament.status == "locked" || $tournament.status == "live")))) {
      error_type = "inputerror"
      error = "Entry is not editable."
    }
  
    db.query weight_class {
      where = $db.weight_class.tournament_id == $tournament.id
      return = {type: "count"}
    } as $wc_count
  
    db.query pickem_pick {
      where = $db.pickem_pick.pickem_entry_id == $entry.id
      return = {type: "count"}
    } as $pick_count
  
    precondition ($wc_count > 0 && $pick_count >= $wc_count) {
      error_type = "inputerror"
      error = "INCOMPLETE: every weight class must have a pick."
    }
  
    db.edit pickem_entry {
      field_name = "id"
      field_value = $entry.id
      data = {
        status      : "submitted"
        submitted_at: now
        updated_at  : now
      }
    } as $updated_entry
  }

  response = $updated_entry
}
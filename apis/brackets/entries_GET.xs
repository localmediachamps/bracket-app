// Get an entry plus all of its picks (owner only).
query "entries/{id}" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    // Entry id
    int id
  }

  stack {
    precondition ($auth[""] != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.get user_bracket {
      field_name = "id"
      field_value = $input.id
    } as $entry
  
    precondition ($entry != null) {
      error_type = "notfound"
      error = "Entry not found."
    }
  
    precondition ($entry.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "You do not own this entry."
    }
  
    db.query user_pick {
      where = $db.user_pick.user_bracket_id == $entry.id
      return = {type: "list"}
    } as $picks
  
    array.map ($picks) {
      by = {
        bracket_match_id: $this.bracket_match_id
        wrestler_id     : $this.picked_wrestler_id
        outcome_status  : $this.outcome_status
        points_available: $this.points_available
        points_earned   : $this.points_earned
      }
    } as $pick_rows
  }

  response = {entry: $entry, picks: $pick_rows}
}
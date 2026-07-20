// Looks up a user_bracket entry and verifies it belongs to the given
// tournament and user. Used by tournaments/{id}/bracket/{weightClassId} to
// check entry_id ownership before merging picks into the bracket view.
function verify_entry_ownership {
  input {
    // user_bracket id to verify
    int entry_id

    // Tournament the entry must belong to
    int tournament_id

    // Requesting user's id
    int user_id
  }

  stack {
    db.get user_bracket {
      field_name = "id"
      field_value = $input.entry_id
    } as $entry

    precondition ($entry != null) {
      error_type = "notfound"
      error = "Entry not found."
    }

    precondition ($entry.tournament_id == $input.tournament_id) {
      error_type = "inputerror"
      error = "Entry does not belong to this tournament."
    }

    precondition ($entry.user_id == $input.user_id) {
      error_type = "accessdenied"
      error = "You do not own this entry."
    }
  }

  response = $entry
}

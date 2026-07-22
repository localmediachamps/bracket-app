// Owner-only toggle for whether this bracket entry's picks are visible to
// other users from the tournament leaderboard. Defaults to private; this is
// the only way to opt in.
query "entries/{id}/visibility" verb=PUT {
  api_group = "brackets"
  auth = "user"

  input {
    // Entry id
    int id

    bool is_public
  }

  stack {
    precondition ($auth.id != null) {
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

    db.edit user_bracket {
      field_name = "id"
      field_value = $entry.id
      data = {is_public: $input.is_public}
    } as $updated
  }

  response = $updated
  guid = "Fq8mZtYs2NwLbXoRcVe6DiK3aHf"
}

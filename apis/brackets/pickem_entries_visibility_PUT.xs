// Owner-only toggle for whether this pick'em entry's picks are visible to
// other users from the tournament leaderboard. Defaults to private; this is
// the only way to opt in.
query "pickem-entries/{id}/visibility" verb=PUT {
  api_group = "brackets"
  auth = "user"

  input {
    // Pick'em entry id
    int id

    bool is_public
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

    db.edit pickem_entry {
      field_name = "id"
      field_value = $entry.id
      data = {is_public: $input.is_public}
    } as $updated
  }

  response = $updated
  guid = "Gr9nAuZt3OxMcYpSdWf7EjL4bIg"
}

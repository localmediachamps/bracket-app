// Owner-only toggle for whether this dual meet entry's picks are visible to
// other users. Defaults to private; this is the only way to opt in.
query "dual-meet-entries/{id}/visibility" verb=PUT {
  api_group = "brackets"
  auth = "user"

  input {
    // Dual meet entry id
    int id

    bool is_public
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get dual_meet_entry {
      field_name = "id"
      field_value = $input.id
    } as $entry

    precondition ($entry != null) {
      error_type = "notfound"
      error = "Dual meet entry not found."
    }

    precondition ($entry.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "You do not own this entry."
    }

    db.edit dual_meet_entry {
      field_name = "id"
      field_value = $entry.id
      data = {is_public: $input.is_public}
    } as $updated
  }

  response = $updated
  guid = "OrQ4Dk3xre1DcskwQaloWv6FNzo"
}

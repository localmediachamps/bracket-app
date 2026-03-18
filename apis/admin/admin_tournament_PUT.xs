query "admin/tournament/{id}" verb=PUT {
  api_group = "Admin"
  description = "Update tournament details. Admin only."
  auth = "user"

  input {
    int id {
      description = "Tournament ID"
    }
    text name? filters=trim {
      description = "Tournament name"
    }
    int year? {
      description = "Tournament year"
    }
    int locks_at? {
      description = "Timestamp when bracket picks are locked"
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin_check

    db.get tournament {
      field_name  = "id"
      field_value = $input.id
    } as $existing

    precondition ($existing != null) {
      error_type = "notfound"
      error      = "Tournament not found."
    }

    // Build new values — fall back to existing if input not provided
    var $new_name {
      value = $existing.name
    }

    conditional {
      if ($input.name != null) {
        var.update $new_name { value = $input.name }
      }
    }

    var $new_year {
      value = $existing.year
    }

    conditional {
      if ($input.year != null) {
        var.update $new_year { value = $input.year }
      }
    }

    var $new_locks_at {
      value = $existing.locks_at
    }

    conditional {
      if ($input.locks_at != null) {
        var.update $new_locks_at { value = $input.locks_at }
      }
    }

    db.edit tournament {
      field_name  = "id"
      field_value = $input.id
      data        = {name: $new_name, year: $new_year, locks_at: $new_locks_at}
    } as $tournament
  }

  response = $tournament
}

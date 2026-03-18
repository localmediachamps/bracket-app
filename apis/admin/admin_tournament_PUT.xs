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

    var $payload {
      value = {}
    }

    conditional {
      if ($input.name != null) {
        var.update $payload {
          value = $payload|set:"name":$input.name
        }
      }
    }

    conditional {
      if ($input.year != null) {
        var.update $payload {
          value = $payload|set:"year":$input.year
        }
      }
    }

    conditional {
      if ($input.locks_at != null) {
        var.update $payload {
          value = $payload|set:"locks_at":$input.locks_at
        }
      }
    }

    db.edit tournament {
      field_name  = "id"
      field_value = $input.id
      data        = $payload
    } as $tournament
  }

  response = $tournament
}

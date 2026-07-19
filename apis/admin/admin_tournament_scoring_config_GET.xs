// Get the tournament scoring config (ARCHITECTURE.md sections 5 and 6:
// GET /admin/tournaments/{id}/scoring-config). Falls back to defaults when unset.
query "admin/tournaments/{id}/scoring-config" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    var $config {
      value = $tournament.scoring_config
    }
  
    conditional {
      if ($config == null) {
        function.run get_default_scoring_config as $default_config
        var.update $config {
          value = $default_config
        }
      }
    }
  }

  response = $config
}
// Get the tournament pick'em config (ARCHITECTURE.md sections 6 and 7:
// GET /admin/tournaments/{id}/pickem-config). Falls back to defaults when unset.
query "admin/tournaments/{id}/pickem-config" verb=GET {
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
      value = $tournament.pickem_config
    }
  
    conditional {
      if ($config == null) {
        function.run get_default_pickem_config as $default_config
        var.update $config {
          value = $default_config
        }
      }
    }
  }

  response = $config
}
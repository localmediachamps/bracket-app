// Update the tournament pick'em config (ARCHITECTURE.md sections 6 and 7:
// PUT /admin/tournaments/{id}/pickem-config).
// Same pattern as scoring-config: when any match is already complete/corrected the
// change is audit-logged with previous/new values; the version is bumped only when
// the config carries a numeric version key (the default pick'em config has none —
// see ARCHITECTURE.md section 7).
query "admin/tournaments/{id}/pickem-config" verb=PUT {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  
    // Full replacement pick'em config (see ARCHITECTURE.md section 7)
    json config
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    precondition ($input.config|is_object) {
      error_type = "inputerror"
      error = "config must be a JSON object."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    var $stored_config {
      value = $tournament.pickem_config
    }
  
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $input.id && ($db.bracket_match.match_status == "complete" || $db.bracket_match.match_status == "corrected")
      return = {type: "count"}
    } as $completed_matches
  
    var $new_config {
      value = $input.config
    }
  
    // Results exist: audit the change; bump version when the config is versioned
    conditional {
      if ($completed_matches > 0) {
        conditional {
          if (($new_config|has:"version") && ($new_config|get:"version":null)|is_int) {
            var $prev_version {
              value = $new_config|get:"version":1
            }
          
            var $next_version {
              value = $prev_version + 1
            }
          
            var.update $new_config {
              value = $new_config|set:"version":$next_version
            }
          }
        }
      
        function.run audit {
          input = {
            actor_id      : $auth.id
            entity_type   : "tournament"
            entity_id     : $input.id
            action        : "pickem_config_changed"
            previous_value: $stored_config
            new_value     : $new_config
          }
        } as $audit_row
      }
    }
  
    db.edit tournament {
      field_name = "id"
      field_value = $input.id
      data = {pickem_config: $new_config}
    } as $updated
  }

  response = $new_config
}
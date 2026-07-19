// Update the tournament scoring config (ARCHITECTURE.md sections 5 and 6:
// PUT /admin/tournaments/{id}/scoring-config).
// When any match is already complete/corrected, the config version is bumped
// (previous stored version + 1) and the change is audit-logged with previous/new
// values. Entries keep the scoring_version they were scored with until the next rescore.
query "admin/tournaments/{id}/scoring-config" verb=PUT {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  
    // Full replacement scoring config (see ARCHITECTURE.md section 5)
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
      value = $tournament.scoring_config
    }
  
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $input.id && ($db.bracket_match.match_status == "complete" || $db.bracket_match.match_status == "corrected")
      return = {type: "count"}
    } as $completed_matches
  
    var $new_config {
      value = $input.config
    }
  
    // Results exist: bump version and audit the change (ARCHITECTURE.md section 5)
    conditional {
      if ($completed_matches > 0) {
        var $prev_version {
          value = 1
        }
      
        conditional {
          if ($stored_config != null) {
            var.update $prev_version {
              value = $stored_config|get:"version":1
            }
          }
        }
      
        var $next_version {
          value = $prev_version + 1
        }
      
        var.update $new_config {
          value = $new_config|set:"version":$next_version
        }
      
        function.run audit {
          input = {
            actor_id      : $auth.id
            entity_type   : "tournament"
            entity_id     : $input.id
            action        : "scoring_config_changed"
            previous_value: $stored_config
            new_value     : $new_config
          }
        } as $audit_row
      }
    }
  
    db.edit tournament {
      field_name = "id"
      field_value = $input.id
      data = {scoring_config: $new_config}
    } as $updated
  }

  response = $new_config
}
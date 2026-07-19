// Publish a tournament: draft|needs_review -> open (ARCHITECTURE.md sections 4 and 6).
// Validates: at least one weight class, every weight class has >= 2 competitors
// and a generated bracket (bracket_match count > 0). Sets published_at. Audited.
query "admin/tournaments/{id}/publish" verb=POST {
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
  
    precondition ($tournament.status == "draft" || $tournament.status == "needs_review") {
      error_type = "inputerror"
      error = "Only draft or needs_review tournaments can be published (current: " ~ $tournament.status ~ ")."
    }
  
    db.query weight_class {
      where = $db.weight_class.tournament_id == $input.id
      return = {type: "list"}
    } as $weight_classes
  
    precondition (($weight_classes|count) >= 1) {
      error_type = "inputerror"
      error = "Cannot publish: tournament has no weight classes."
    }
  
    // Validate every weight class: >= 2 competitors and matches generated
    var $invalid {
      value = []
    }
  
    foreach ($weight_classes) {
      each as $wc {
        db.query wrestler {
          where = $db.wrestler.weight_class_id == $wc.id
          return = {type: "count"}
        } as $competitor_count
      
        db.query bracket_match {
          where = $db.bracket_match.weight_class_id == $wc.id
          return = {type: "count"}
        } as $match_count
      
        conditional {
          if ($competitor_count < 2) {
            array.push $invalid {
              value = ($wc.weight|to_text) ~ " lbs has fewer than 2 competitors"
            }
          }
        }
      
        conditional {
          if ($match_count == 0) {
            array.push $invalid {
              value = ($wc.weight|to_text) ~ " lbs has no generated bracket"
            }
          }
        }
      }
    }
  
    precondition (($invalid|count) == 0) {
      error_type = "inputerror"
      error = "Cannot publish: " ~ ($invalid|join:"; ") ~ "."
    }
  
    db.edit tournament {
      field_name = "id"
      field_value = $input.id
      data = {status: "open", published_at: now}
    } as $updated
  
    function.run audit {
      input = {
        actor_id      : $auth.id
        entity_type   : "tournament"
        entity_id     : $input.id
        action        : "publish"
        previous_value: {status: $tournament.status}
        new_value     : {status: "open"}
      }
    } as $audit_row
  
    // MVP: no tournament_open fan-out here — a freshly published tournament has no
    // prior entrants or group members to notify (see ARCHITECTURE.md section 10).
  }

  response = $updated
}
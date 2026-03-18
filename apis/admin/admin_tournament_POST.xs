// Create a new tournament with default scoring rules and weight classes. Admin only.
query "admin/tournament" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament name
    text name filters=trim
  
    // Tournament year
    int year
  
    // Timestamp when bracket picks are locked
    int locks_at
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin_check
  
    db.add tournament {
      data = {
        created_at: now
        name      : $input.name
        year      : $input.year
        status    : "draft"
        locks_at  : $input.locks_at
      }
    } as $tournament
  
    function.run get_default_scoring_config as $scoring_rules
    foreach ($scoring_rules) {
      each as $rule {
        db.add scoring_rule {
          data = {
            tournament_id: $tournament.id
            round_code   : $rule.round_code
            points       : $rule.points
          }
        } as $new_rule
      }
    }
  
    var $weights {
      value = [125, 133, 141, 149, 157, 165, 174, 184, 197, 285]
    }
  
    foreach ($weights) {
      each as $w {
        db.add weight_class {
          data = {
            created_at   : now
            tournament_id: $tournament.id
            weight       : $w
            status       : "pending"
          }
        } as $wc
      }
    }
  }

  response = $tournament
}
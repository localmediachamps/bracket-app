// Add a weight class to a tournament (ARCHITECTURE.md section 6: POST /admin/tournaments/{id}/weights).
// Creates the weight class only — competitors are added later via PUT /admin/weights/{id}/competitors,
// which runs bracket generation once competitors exist.
query "admin/tournaments/{id}/weights" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  
    // Weight in lbs (e.g. 125)
    int weight
  
    // Display name, default "<weight> lbs"
    text? name? filters=trim
  
    // Ordering among weight classes, default: appended at the end
    int? display_order?
  
    // Bracket template (default ncaa_33)
    text? template? filters=trim
  
    // Consolation mode passed to bracket_generate at generation time (none | full)
    text? consolation? filters=trim|lower
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
  
    db.query weight_class {
      where = $db.weight_class.tournament_id == $input.id && $db.weight_class.weight == $input.weight
      return = {type: "count"}
    } as $duplicate_count
  
    precondition ($duplicate_count == 0) {
      error_type = "inputerror"
      error = "Weight class " ~ ($input.weight|to_text) ~ " already exists for this tournament."
    }
  
    db.query weight_class {
      where = $db.weight_class.tournament_id == $input.id
      return = {type: "count"}
    } as $existing_count
  
    var $wc_default_name {
      value = ($input.weight|to_text) ~ " lbs"
    }
  
    var $wc_name {
      value = $input.name|first_notempty:$wc_default_name
    }
  
    var $wc_default_order {
      value = $existing_count + 1
    }
  
    var $wc_order {
      value = $input.display_order|first_notnull:$wc_default_order
    }
  
    var $wc_template {
      value = $input.template|first_notempty:"ncaa_33"
    }
  
    // DEVIATION: weight_class has no consolation column — the consolation mode is not
    // persisted here; it is passed through to bracket_generate when a bracket is
    // (re)generated via POST /admin/weights/{id}/generate-bracket.
    db.add weight_class {
      data = {
        created_at      : now
        tournament_id   : $input.id
        weight          : $input.weight
        name            : $wc_name
        display_order   : $wc_order
        bracket_template: $wc_template
        status          : "pending"
        competitor_count: 0
      }
    } as $weight_class
  }

  response = $weight_class
}
// (Re)generate the bracket for a weight class (ARCHITECTURE.md section 6:
// POST /admin/weights/{id}/generate-bracket).
// Runs bracket_generate (which deletes existing matches and rebuilds) plus its
// self-check, and returns {matches_created, issues}. Guarded: refused once any
// match in the weight class is complete or corrected.
query "admin/weights/{id}/generate-bracket" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Weight class ID
    int id
  
    // Template override (e.g. ncaa_33, field_32) — stored on the weight class
    text? template? filters=trim
  
    // Championship field size override (e.g. 32) — stored on the weight class
    int? bracket_size?
  
    // Consolation mode passed through to the generator (none | full)
    text? consolation? filters=trim|lower
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get weight_class {
      field_name = "id"
      field_value = $input.id
    } as $weight_class
  
    precondition ($weight_class != null) {
      error_type = "notfound"
      error = "Weight class not found."
    }
  
    db.query bracket_match {
      where = $db.bracket_match.weight_class_id == $input.id && $db.bracket_match.is_bye == false && ($db.bracket_match.match_status == "complete" || $db.bracket_match.match_status == "corrected")
      return = {type: "count"}
    } as $completed_matches
  
    precondition ($completed_matches == 0) {
      error_type = "inputerror"
      error = "Cannot regenerate: this weight class already has completed matches."
    }
  
    // Persist template / bracket-size overrides before generating
    var $wc_payload {
      value = {}
    }
  
    var.update $wc_payload {
      value = $wc_payload
        |set_ifnotnull:"bracket_template":$input.template
        |set_ifnotnull:"bracket_size":$input.bracket_size
    }
  
    conditional {
      if (($wc_payload|keys|count) > 0) {
        db.patch weight_class {
          field_name = "id"
          field_value = $input.id
          data = $wc_payload
        } as $wc_patched
      
        var.update $weight_class {
          value = $wc_patched
        }
      }
    }
  
    var $gen_template {
      value = $weight_class.bracket_template|first_notempty:"ncaa_33"
    }
  
    function.run bracket_generate {
      input = {
        weight_class_id: $input.id
        tournament_id  : $weight_class.tournament_id
        template       : $gen_template
        bracket_size   : $weight_class.bracket_size
        consolation    : $input.consolation
      }
    } as $gen_result
  
    var $matches_created {
      value = $gen_result|get:"matches_created":null
    }
  
    var $issues {
      value = $gen_result|get:"issues":[]
    }
  }

  response = {matches_created: $matches_created, issues: $issues}
}
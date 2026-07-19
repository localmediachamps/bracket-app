// Bulk replace competitors for a weight class (ARCHITECTURE.md section 6:
// PUT /admin/weights/{id}/competitors).
// Allowed only while the tournament is draft|open AND the weight class has no
// completed/corrected matches. Deletes existing wrestler rows, inserts the new list
// (normalized_name = name lowercased), updates competitor_count, then re-runs
// bracket_generate to re-seat the bracket (safe: no results exist by the guard above).
query "admin/weights/{id}/competitors" verb=PUT {
  api_group = "admin"
  auth = "user"

  input {
    // Weight class ID
    int id
  
    // Full replacement list: [{seed, name, school, record?, withdrawn?}]
    json[] competitors
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
  
    db.get tournament {
      field_name = "id"
      field_value = $weight_class.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    precondition ($tournament.status == "draft" || $tournament.status == "open") {
      error_type = "inputerror"
      error = "Competitors can only be replaced while the tournament is draft or open (current: " ~ $tournament.status ~ ")."
    }
  
    db.query bracket_match {
      where = $db.bracket_match.weight_class_id == $input.id && ($db.bracket_match.match_status == "complete" || $db.bracket_match.match_status == "corrected")
      return = {type: "count"}
    } as $completed_matches
  
    precondition ($completed_matches == 0) {
      error_type = "inputerror"
      error = "Cannot replace competitors: this weight class already has completed matches."
    }
  
    // Validate the payload before writing: names present, seeds unique
    // (unseeded competitors fall back to their 1-based position).
    var $seen_seeds {
      value = []
    }
  
    var $check_pos {
      value = 0
    }
  
    foreach ($input.competitors) {
      each as $c {
        math.add $check_pos {
          value = 1
        }
      
        var $check_seed {
          value = $c|get:"seed":null
        }
      
        conditional {
          if ($check_seed == null) {
            var.update $check_seed {
              value = $check_pos
            }
          }
        }
      
        precondition (($seen_seeds|some:$$ == $check_seed) == false) {
          error_type = "inputerror"
          error = "Duplicate seed " ~ ($check_seed|to_text) ~ " in competitors."
        }
      
        array.push $seen_seeds {
          value = $check_seed
        }
      
        precondition ($c.name != null && $c.name != "") {
          error_type = "inputerror"
          error = "Every competitor needs a name."
        }
      }
    }
  
    // Replace strategy: delete existing wrestler rows, insert the new list,
    // update competitor_count — atomically.
    // Replace competitors for the weight class
    db.transaction {
      stack {
        db.query wrestler {
          where = $db.wrestler.weight_class_id == $input.id
          return = {type: "list"}
          output = ["id"]
        } as $existing_wrestlers
      
        foreach ($existing_wrestlers) {
          each as $ew {
            db.del wrestler {
              field_name = "id"
              field_value = $ew.id
            }
          }
        }
      
        var $insert_pos {
          value = 0
        }
      
        foreach ($input.competitors) {
          each as $c {
            math.add $insert_pos {
              value = 1
            }
          
            var $insert_seed {
              value = $c|get:"seed":null
            }
          
            conditional {
              if ($insert_seed == null) {
                var.update $insert_seed {
                  value = $insert_pos
                }
              }
            }
          
            var $c_school {
              value = $c.school|first_notempty:""
            }
          
            var $c_normalized {
              value = $c.name|to_lower
            }
          
            var $c_withdrawn {
              value = $c.withdrawn|first_notnull:false
            }
          
            db.add wrestler {
              data = {
                created_at     : now
                tournament_id  : $tournament.id
                weight_class_id: $input.id
                seed           : $insert_seed
                name           : $c.name
                school         : $c_school
                record         : $c.record
                normalized_name: $c_normalized
                source_raw     : null
                withdrawn      : $c_withdrawn
              }
            } as $new_wrestler
          }
        }
      
        db.edit weight_class {
          field_name = "id"
          field_value = $input.id
          data = {competitor_count: $input.competitors|count}
        } as $wc_updated
      }
    }
  
    // Re-seat the bracket. bracket_generate deletes existing matches for the
    // weight class and rebuilds, so stale match rows are cleared even when the
    // new competitor list is smaller (or empty).
    var $gen_template {
      value = $weight_class.bracket_template|first_notempty:"ncaa_33"
    }
  
    function.run bracket_generate {
      input = {
        weight_class_id: $input.id
        tournament_id  : $tournament.id
        template       : $gen_template
        bracket_size   : $weight_class.bracket_size
      }
    } as $gen_result
  
    var $issues {
      value = []
    }
  
    var $gen_issues {
      value = $gen_result|get:"issues":[]
    }
  
    conditional {
      if ($gen_issues != null) {
        array.merge $issues {
          value = $gen_issues
        }
      }
    }
  }

  response = {count: $input.competitors|count, issues: $issues}
}
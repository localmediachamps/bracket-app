// Full manual tournament create (ARCHITECTURE.md section 6: POST /admin/tournaments).
// Creates the tournament (status draft), its weight classes, bulk-inserts competitors,
// generates each bracket via bracket_generate, and collects generator self-check issues.
// Returns {tournament, weight_classes (with competitor counts), issues}.
query "admin/tournaments" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament name
    text name filters=trim|min:1
  
    // Tournament year
    int year
  
    // Optional slug override — auto-generated from name+year when absent
    text? slug? filters=trim|lower
  
    text? description?
    text? location?
  
    // Event start date (ISO date)
    date? start_date?
  
    // Event end date (ISO date)
    date? end_date?
  
    // Prediction deadline — entries lock when this passes
    timestamp? locks_at?
  
    // public | unlisted (default public)
    text? visibility? filters=trim|lower
  
    // Enabled game modes, default ["bracket","pickem"]
    json? game_modes?
  
    // Scoring config override, default via get_default_scoring_config
    json? scoring_config?
  
    // Pick'em config override, default via get_default_pickem_config
    json? pickem_config?
  
    // [{weight, name?, display_order?, template?, consolation?, competitors: [{seed, name, school, record?}]}]
    json[]? weight_classes?
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    precondition ($input.visibility == null || $input.visibility == "public" || $input.visibility == "unlisted") {
      error_type = "inputerror"
      error = "visibility must be public or unlisted."
    }
  
    var $wc_inputs {
      value = $input.weight_classes
    }
  
    conditional {
      if ($wc_inputs == null) {
        var.update $wc_inputs {
          value = []
        }
      }
    }
  
    // ---------------------------------------------------------------
    // Validate the weight class payload before writing anything:
    // duplicate weights, duplicate seeds within a weight, missing names.
    // ---------------------------------------------------------------
    var $seen_weights {
      value = []
    }
  
    foreach ($wc_inputs) {
      each as $wc_in {
        precondition ($wc_in.weight != null) {
          error_type = "inputerror"
          error = "Every weight class needs a weight."
        }
      
        precondition (($seen_weights|some:$$ == $wc_in.weight) == false) {
          error_type = "inputerror"
          error = "Duplicate weight " ~ ($wc_in.weight|to_text) ~ " in weight_classes."
        }
      
        array.push $seen_weights {
          value = $wc_in.weight
        }
      
        var $check_competitors {
          value = $wc_in|get:"competitors":null
        }
      
        conditional {
          if ($check_competitors == null) {
            var.update $check_competitors {
              value = []
            }
          }
        }
      
        var $check_seeds {
          value = []
        }
      
        var $check_pos {
          value = 0
        }
      
        foreach ($check_competitors) {
          each as $c {
            math.add $check_pos {
              value = 1
            }
          
            var $check_seed {
              value = $c|get:"seed":null
            }
          
            conditional {
              if ($check_seed == null) {
                // Unseeded competitors fall back to their 1-based position
                var.update $check_seed {
                  value = $check_pos
                }
              }
            }
          
            precondition (($check_seeds|some:$$ == $check_seed) == false) {
              error_type = "inputerror"
              error = "Duplicate seed " ~ ($check_seed|to_text) ~ " in weight " ~ ($wc_in.weight|to_text) ~ "."
            }
          
            array.push $check_seeds {
              value = $check_seed
            }
          
            precondition ($c.name != null && $c.name != "") {
              error_type = "inputerror"
              error = "Every competitor needs a name (weight " ~ ($wc_in.weight|to_text) ~ ")."
            }
          }
        }
      }
    }
  
    // ---------------------------------------------------------------
    // Resolve a unique slug (input override or slugify(name year), -2, -3, ...)
    // ---------------------------------------------------------------
    var $slug_source {
      value = $input.name ~ " " ~ ($input.year|to_text)
    }
  
    conditional {
      if ($input.slug != null && ($input.slug|strlen) > 0) {
        var.update $slug_source {
          value = $input.slug
        }
      }
    }
  
    function.run slugify {
      input = {text: $slug_source}
    } as $slug_base
  
    var $slug {
      value = $slug_base
    }
  
    var $slug_suffix {
      value = 1
    }
  
    var $slug_taken {
      value = true
    }
  
    while (`$slug_taken`) {
      each {
        db.query tournament {
          where = $db.tournament.slug == $slug
          return = {type: "count"}
        } as $slug_hits
      
        conditional {
          if ($slug_hits == 0) {
            var.update $slug_taken {
              value = false
            }
          }
        
          else {
            math.add $slug_suffix {
              value = 1
            }
          
            var.update $slug {
              value = $slug_base ~ "-" ~ ($slug_suffix|to_text)
            }
          }
        }
      }
    }
  
    // ---------------------------------------------------------------
    // Config defaults
    // ---------------------------------------------------------------
    var $game_modes {
      value = $input.game_modes
    }
  
    conditional {
      if ($game_modes == null) {
        var.update $game_modes {
          value = ["bracket", "pickem"]
        }
      }
    }
  
    var $scoring_config {
      value = $input.scoring_config
    }
  
    conditional {
      if ($scoring_config == null) {
        function.run get_default_scoring_config as $default_scoring
        var.update $scoring_config {
          value = $default_scoring
        }
      }
    }
  
    var $pickem_config {
      value = $input.pickem_config
    }
  
    conditional {
      if ($pickem_config == null) {
        function.run get_default_pickem_config as $default_pickem
        var.update $pickem_config {
          value = $default_pickem
        }
      }
    }
  
    var $visibility {
      value = $input.visibility|first_notempty:"public"
    }
  
    // ---------------------------------------------------------------
    // Create the tournament (draft)
    // ---------------------------------------------------------------
    db.add tournament {
      data = {
        created_at    : now
        name          : $input.name
        year          : $input.year
        slug          : $slug
        description   : $input.description
        location      : $input.location
        start_date    : $input.start_date
        end_date      : $input.end_date
        locks_at      : $input.locks_at
        status        : "draft"
        visibility    : $visibility
        game_modes    : $game_modes
        scoring_config: $scoring_config
        pickem_config : $pickem_config
        created_by    : $auth.id
      }
    } as $tournament
  
    // ---------------------------------------------------------------
    // Weight classes + competitors + bracket generation
    // ---------------------------------------------------------------
    var $weight_summaries {
      value = []
    }
  
    var $issues {
      value = []
    }
  
    var $wc_pos {
      value = 0
    }
  
    foreach ($wc_inputs) {
      each as $wc_in {
        math.add $wc_pos {
          value = 1
        }
      
        var $wc_default_name {
          value = ($wc_in.weight|to_text) ~ " lbs"
        }
      
        var $wc_name {
          value = ($wc_in|get:"name":null)|first_notempty:$wc_default_name
        }
      
        var $wc_order {
          value = ($wc_in|get:"display_order":null)|first_notnull:$wc_pos
        }
      
        var $wc_template {
          value = ($wc_in|get:"template":null)|first_notempty:"ncaa_33"
        }
      
        var $competitors {
          value = $wc_in|get:"competitors":null
        }
      
        conditional {
          if ($competitors == null) {
            var.update $competitors {
              value = []
            }
          }
        }
      
        var $competitor_count {
          value = $competitors|count
        }
      
        db.add weight_class {
          data = {
            created_at      : now
            tournament_id   : $tournament.id
            weight          : $wc_in.weight
            name            : $wc_name
            display_order   : $wc_order
            bracket_template: $wc_template
            status          : "pending"
            competitor_count: $competitor_count
          }
        } as $weight_class
      
        var $comp_pos {
          value = 0
        }
      
        foreach ($competitors) {
          each as $c {
            math.add $comp_pos {
              value = 1
            }
          
            var $cseed {
              value = $c|get:"seed":null
            }
          
            conditional {
              if ($cseed == null) {
                var.update $cseed {
                  value = $comp_pos
                }
              }
            }
          
            var $c_school {
              value = ($c|get:"school":null)|first_notempty:""
            }
          
            var $c_normalized {
              value = $c.name|to_lower
            }
          
            db.add wrestler {
              data = {
                created_at     : now
                tournament_id  : $tournament.id
                weight_class_id: $weight_class.id
                seed           : $cseed
                name           : $c.name
                school         : $c_school
                record         : $c|get:"record":null
                normalized_name: $c_normalized
                source_raw     : null
                withdrawn      : ($c|get:"withdrawn":null)|first_notnull:false
              }
            } as $new_wrestler
          }
        }
      
        // Generate the bracket when there are enough competitors to seed one.
        // (Fresh weight class, so skipping generation leaves no stale matches.)
        conditional {
          if ($competitor_count >= 2) {
            function.run bracket_generate {
              input = {
                weight_class_id: $weight_class.id
                tournament_id  : $tournament.id
                template       : $wc_template
                consolation    : $wc_in|get:"consolation":null
              }
            } as $gen_result
          
            var $gen_issues {
              value = $gen_result|get:"issues":[]
            }
          
            conditional {
              if ($gen_issues != null) {
                foreach ($gen_issues) {
                  each as $gi {
                    array.push $issues {
                      value = {
                        weight_class_id: $weight_class.id
                        weight         : $wc_in.weight
                        issue          : $gi
                      }
                    }
                  }
                }
              }
            }
          }
        }
      
        array.push $weight_summaries {
          value = {
            id              : $weight_class.id
            weight          : $wc_in.weight
            name            : $wc_name
            display_order   : $wc_order
            bracket_template: $wc_template
            competitor_count: $competitor_count
          }
        }
      }
    }
  
    function.run audit {
      input = {
        actor_id   : $auth.id
        entity_type: "tournament"
        entity_id  : $tournament.id
        action     : "tournament_created"
        new_value  : $tournament
      }
    } as $audit_row
  }

  response = {
    tournament    : $tournament
    weight_classes: $weight_summaries
    issues        : $issues
  }
}
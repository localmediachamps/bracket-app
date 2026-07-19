// Confirm a reviewed PDF extraction (ARCHITECTURE.md section 6:
// POST /admin/documents/{id}/confirm).
// Takes the REVIEWED weights payload (may differ from the raw extraction) and either
// adds to an existing tournament (tournament_id, or the document's linked tournament)
// or creates a new one (name + year required). Weight classes are get-or-created by
// (tournament_id, weight); their wrestlers are replaced with the payload and brackets
// are generated per weight. The document becomes confirmed and the tournament's
// source_document_id is linked. Re-confirming is idempotent (replace semantics).
query "admin/documents/{id}/confirm" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Uploaded document ID
    int id
  
    // Existing tournament to add the weights to (optional)
    int? tournament_id?
  
    // New tournament name (required when no tournament is targeted)
    text? name? filters=trim
  
    // New tournament year (required when no tournament is targeted)
    int? year?
  
    text? location?
    date? start_date?
    timestamp? locks_at?
  
    // Reviewed payload: [{weight, template?, wrestlers: [{seed, name, school, record?}]}]
    json[] weights
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get uploaded_document {
      field_name = "id"
      field_value = $input.id
    } as $document
  
    precondition ($document != null) {
      error_type = "notfound"
      error = "Document not found."
    }
  
    precondition ($document.processing_status == "needs_review" || $document.processing_status == "confirmed") {
      error_type = "inputerror"
      error = "Document is not in a confirmable state (current: " ~ $document.processing_status ~ ")."
    }
  
    // Resolve the target tournament: explicit input, else the document link, else create
    var $target_tournament_id {
      value = $input.tournament_id
        |first_notnull:$document.tournament_id
    }
  
    var $tournament {
      value = null
    }
  
    conditional {
      if ($target_tournament_id != null) {
        db.get tournament {
          field_name = "id"
          field_value = $target_tournament_id
        } as $existing_tournament
      
        precondition ($existing_tournament != null) {
          error_type = "notfound"
          error = "Tournament not found."
        }
      
        var.update $tournament {
          value = $existing_tournament
        }
      }
    
      else {
        precondition ($input.name != null && $input.year != null) {
          error_type = "inputerror"
          error = "name and year are required when tournament_id is not provided."
        }
      
        var $slug_source {
          value = $input.name ~ " " ~ ($input.year|to_text)
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
      
        function.run get_default_scoring_config as $default_scoring
        function.run get_default_pickem_config as $default_pickem
        db.add tournament {
          data = {
            created_at        : now
            name              : $input.name
            year              : $input.year
            slug              : $slug
            location          : $input.location
            start_date        : $input.start_date
            locks_at          : $input.locks_at
            status            : "draft"
            visibility        : "public"
            game_modes        : ["bracket", "pickem"]
            scoring_config    : $default_scoring
            pickem_config     : $default_pickem
            created_by        : $auth.id
            source_document_id: $input.id
          }
        } as $new_tournament
      
        var.update $tournament {
          value = $new_tournament
        }
      }
    }
  
    // Link the source document on an existing tournament when not already set
    conditional {
      if ($tournament.source_document_id == null) {
        db.edit tournament {
          field_name = "id"
          field_value = $tournament.id
          data = {source_document_id: $input.id}
        } as $tournament_linked
      
        var.update $tournament {
          value = $tournament_linked
        }
      }
    }
  
    // ---------------------------------------------------------------
    // Weights: get-or-create weight class, replace wrestlers, generate bracket
    // ---------------------------------------------------------------
    var $weights_created {
      value = 0
    }
  
    var $issues {
      value = []
    }
  
    var $seen_weights {
      value = []
    }
  
    foreach ($input.weights) {
      each as $w_in {
        precondition ($w_in.weight != null) {
          error_type = "inputerror"
          error = "Every weight class needs a weight."
        }
      
        precondition (($seen_weights|some:$$ == $w_in.weight) == false) {
          error_type = "inputerror"
          error = "Duplicate weight " ~ ($w_in.weight|to_text) ~ " in weights."
        }
      
        array.push $seen_weights {
          value = $w_in.weight
        }
      
        var $w_default_name {
          value = ($w_in.weight|to_text) ~ " lbs"
        }
      
        var $w_template {
          value = ($w_in|get:"template":null)|first_notempty:"ncaa_33"
        }
      
        db.query weight_class {
          where = $db.weight_class.tournament_id == $tournament.id && $db.weight_class.weight == $w_in.weight
          return = {type: "single"}
        } as $wc
      
        conditional {
          if ($wc == null) {
            db.add weight_class {
              data = {
                created_at      : now
                tournament_id   : $tournament.id
                weight          : $w_in.weight
                name            : $w_default_name
                display_order   : 0
                bracket_template: $w_template
                status          : "pending"
                competitor_count: 0
              }
            } as $wc_new
          
            var.update $wc {
              value = $wc_new
            }
          
            math.add $weights_created {
              value = 1
            }
          }
        }
      
        var $wrestler_list {
          value = $w_in|get:"wrestlers":null
        }
      
        conditional {
          if ($wrestler_list == null) {
            var.update $wrestler_list {
              value = []
            }
          }
        }
      
        // Validate the reviewed wrestler payload before writing
        var $seen_seeds {
          value = []
        }
      
        var $check_pos {
          value = 0
        }
      
        foreach ($wrestler_list) {
          each as $wr {
            math.add $check_pos {
              value = 1
            }
          
            var $check_seed {
              value = $wr|get:"seed":null
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
              error = "Duplicate seed " ~ ($check_seed|to_text) ~ " in weight " ~ ($w_in.weight|to_text) ~ "."
            }
          
            array.push $seen_seeds {
              value = $check_seed
            }
          
            precondition ($wr.name != null && $wr.name != "") {
              error_type = "inputerror"
              error = "Every wrestler needs a name (weight " ~ ($w_in.weight|to_text) ~ ")."
            }
          }
        }
      
        // Replace wrestlers with the reviewed payload (import semantics)
        db.query wrestler {
          where = $db.wrestler.weight_class_id == $wc.id
          return = {type: "list"}
          output = ["id"]
        } as $old_wrestlers
      
        foreach ($old_wrestlers) {
          each as $ow {
            db.del wrestler {
              field_name = "id"
              field_value = $ow.id
            }
          }
        }
      
        var $insert_pos {
          value = 0
        }
      
        foreach ($wrestler_list) {
          each as $wr {
            math.add $insert_pos {
              value = 1
            }
          
            var $insert_seed {
              value = $wr|get:"seed":null
            }
          
            conditional {
              if ($insert_seed == null) {
                var.update $insert_seed {
                  value = $insert_pos
                }
              }
            }
          
            var $wr_school {
              value = $wr.school|first_notempty:""
            }
          
            var $wr_normalized {
              value = $wr.name|to_lower
            }
          
            db.add wrestler {
              data = {
                created_at     : now
                tournament_id  : $tournament.id
                weight_class_id: $wc.id
                seed           : $insert_seed
                name           : $wr.name
                school         : $wr_school
                record         : $wr.record
                normalized_name: $wr_normalized
                source_raw     : null
                withdrawn      : false
              }
            } as $new_wrestler
          }
        }
      
        var $wc_existing_template {
          value = $wc.bracket_template|first_notempty:"ncaa_33"
        }
      
        var $wc_template {
          value = ($w_in|get:"template":null)|first_notempty:$wc_existing_template
        }
      
        db.edit weight_class {
          field_name = "id"
          field_value = $wc.id
          data = {
            competitor_count: $wrestler_list|count
            bracket_template: $wc_template
          }
        } as $wc_updated
      
        // Generate the bracket when there are enough competitors to seed one
        conditional {
          if (($wrestler_list|count) >= 2) {
            function.run bracket_generate {
              input = {
                weight_class_id: $wc.id
                tournament_id  : $tournament.id
                template       : $wc_updated.bracket_template
                bracket_size   : $wc_updated.bracket_size
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
                        weight_class_id: $wc.id
                        weight         : $w_in.weight
                        issue          : $gi
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  
    db.edit uploaded_document {
      field_name = "id"
      field_value = $input.id
      data = {
        processing_status: "confirmed"
        tournament_id    : $tournament.id
      }
    } as $document_confirmed
  
    function.run audit {
      input = {
        actor_id   : $auth.id
        entity_type: "tournament"
        entity_id  : $tournament.id
        action     : "import_confirmed"
        metadata   : {document_id: $input.id}
      }
    } as $audit_row
  }

  response = {
    tournament_id  : $tournament.id
    weights_created: $weights_created
    issues         : $issues
  }
}
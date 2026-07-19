// Scraper entry point: receives a batch of raw extracted results for one
// results_source_config and pushes each through the ingestion pipeline
// (parsed -> normalize_candidate -> match_candidate, which may auto-approve).
// Dedupe is on the stable (results_source_config_id, external_match_key) pair;
// repeats are skipped and counted, never reprocessed.
// Each candidate runs inside try_catch so one bad row cannot kill the batch —
// failures are marked status=failed and counted. If the pipeline already
// parked a candidate as a conflict (e.g. a 409 downstream-complete from
// approve_candidate) that status is kept and counted as a conflict instead.
// Source health: a clean batch stamps last_checked_at + last_successful_at and
// health_status=healthy; a batch with failures stamps last_checked_at, sets
// health_status=degraded and records a summary in last_error.
// When at least one candidate was auto-approved the tournament is rescored.
// Ingest a batch of raw result candidates for one source config
function ingest_candidates {
  input {
    // results_source_config.id the batch belongs to
    int results_source_config_id
  
    // Raw candidates: [{external_match_key, source_weight_class, source_round,
    // source_winner, source_winner_school, source_loser, source_loser_school,
    // source_score, source_victory_type, raw_fragment?, occurred_at?,
    // extraction_confidence?}] — capped at 500 per call
    json candidates
  
    // Admin user id when pushed via the admin endpoint (null for tasks)
    int? actor_id?
  }

  stack {
    db.get results_source_config {
      field_name = "id"
      field_value = $input.results_source_config_id
    } as $config
  
    precondition ($config != null) {
      error_type = "notfound"
      error = "Source config not found."
    }
  
    var $candidates {
      value = $input.candidates|safe_array
    }
  
    precondition (($candidates|count) <= 500) {
      error_type = "inputerror"
      error = "Batch is capped at 500 candidates per call."
    }
  
    var $received {
      value = $candidates|count
    }
  
    var $created {
      value = 0
    }
  
    var $duplicates {
      value = 0
    }
  
    var $auto_approved {
      value = 0
    }
  
    var $needs_review {
      value = 0
    }
  
    var $conflicts {
      value = 0
    }
  
    var $failed {
      value = 0
    }
  
    foreach ($candidates) {
      each as $raw {
        var $new_candidate_id {
          value = null
        }
      
        try_catch {
          try {
            var $ext_key {
              value = $raw|get:"external_match_key":null
            }
          
            conditional {
              if (($ext_key == null) || ((($ext_key|to_text|trim)|strlen) == 0)) {
                throw {
                  name = "inputerror"
                  value = "Candidate is missing external_match_key."
                }
              }
            }
          
            // dedupe on the stable (source, key) pair
            db.query external_result_candidate {
              where = $db.external_result_candidate.results_source_config_id == $input.results_source_config_id && $db.external_result_candidate.external_match_key == $ext_key
              return = {type: "list"}
            } as $dupes
          
            conditional {
              if (($dupes|count) > 0) {
                math.add $duplicates {
                  value = 1
                }
              }
            
              else {
                // Build the row inline as an object literal (nullable columns
                // simply receive null when the raw field is absent)
                db.add external_result_candidate {
                  data = {
                    results_source_config_id: $input.results_source_config_id
                    tournament_id           : $config.tournament_id
                    external_match_key      : $ext_key
                    status                  : "parsed"
                    extraction_confidence   : (($raw|get:"extraction_confidence":null)|first_notnull:0)
                    source_weight_class     : $raw|get:"source_weight_class":null
                    source_round            : $raw|get:"source_round":null
                    source_winner           : $raw|get:"source_winner":null
                    source_winner_school    : $raw|get:"source_winner_school":null
                    source_loser            : $raw|get:"source_loser":null
                    source_loser_school     : $raw|get:"source_loser_school":null
                    source_score            : $raw|get:"source_score":null
                    source_victory_type     : $raw|get:"source_victory_type":null
                    raw_fragment            : $raw|get:"raw_fragment":null
                    occurred_at             : $raw|get:"occurred_at":null
                  }
                } as $new_candidate
              
                var.update $new_candidate_id {
                  value = $new_candidate.id
                }
              
                math.add $created {
                  value = 1
                }
              
                // inline pipeline: normalize then match (match may auto-approve)
                function.run normalize_candidate {
                  input = {candidate_id: $new_candidate.id}
                } as $normalized_candidate
              
                function.run match_candidate {
                  input = {candidate_id: $new_candidate.id}
                } as $matched_candidate
              
                conditional {
                  if ($matched_candidate.status == "auto_approved") {
                    math.add $auto_approved {
                      value = 1
                    }
                  }
                
                  elseif ($matched_candidate.status == "needs_review") {
                    math.add $needs_review {
                      value = 1
                    }
                  }
                
                  elseif ($matched_candidate.status == "conflict") {
                    math.add $conflicts {
                      value = 1
                    }
                  }
                }
              }
            }
          }
        
          catch {
            // One bad candidate must not kill the batch. If the pipeline already
            // parked it as a conflict (e.g. 409 downstream-complete on auto-approve),
            // keep that status and count it as a conflict rather than a failure.
            conditional {
              if ($new_candidate_id != null) {
                db.get external_result_candidate {
                  field_name = "id"
                  field_value = $new_candidate_id
                } as $after_error
              
                conditional {
                  if ($after_error != null) {
                    conditional {
                      if ($after_error.status == "conflict") {
                        math.add $conflicts {
                          value = 1
                        }
                      }
                    
                      elseif (($after_error.status != "approved") && ($after_error.status != "auto_approved")) {
                        db.edit external_result_candidate {
                          field_name = "id"
                          field_value = $new_candidate_id
                          data = {status: "failed"}
                        } as $failed_candidate
                      
                        math.add $failed {
                          value = 1
                        }
                      }
                    }
                  }
                
                  else {
                    math.add $failed {
                      value = 1
                    }
                  }
                }
              }
            
              else {
                math.add $failed {
                  value = 1
                }
              }
            }
          
            debug.log {
              value = {
                event    : "ingest_candidate_failed"
                source_id: $input.results_source_config_id
                error    : $error.message
              }
            }
          }
        }
      }
    }
  
    // Source health bookkeeping
    conditional {
      if ($failed > 0) {
        db.edit results_source_config {
          field_name = "id"
          field_value = $config.id
          data = {
            last_checked_at: "now"
            health_status  : "degraded"
            last_error     : $failed ~ " of " ~ $received ~ " candidates failed ingestion"
            updated_at     : "now"
          }
        } as $config_health_update
      }
    
      else {
        db.edit results_source_config {
          field_name = "id"
          field_value = $config.id
          data = {
            last_checked_at   : "now"
            last_successful_at: "now"
            health_status     : "healthy"
            last_error        : null
            updated_at        : "now"
          }
        } as $config_health_update
      }
    }
  
    // Auto-approved results already advanced their matches; rescore once
    conditional {
      if ($auto_approved > 0) {
        function.run rescore_tournament {
          input = {tournament_id: $config.tournament_id}
        } as $rescore_summary
      }
    }
  
    var $summary {
      value = {
        received     : $received
        created      : $created
        duplicates   : $duplicates
        auto_approved: $auto_approved
        needs_review : $needs_review
        conflicts    : $conflicts
        failed       : $failed
      }
    }
  }

  response = $summary
}
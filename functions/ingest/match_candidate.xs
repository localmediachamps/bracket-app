// Matches a normalized external_result_candidate to an internal bracket_match
// (ingestion pipeline step 3: normalized -> matched | needs_review | conflict).
// Looks in the resolved weight class for matches whose two participants are
// exactly the identified winner/loser pair (in either slot order):
//   - exactly one pair match, pending|in_progress -> matched, confidence 1.0
//   - exactly one pair match that already has a result -> confidence 0.85,
//     status conflict, ingestion_conflict row (existing_result, or
//     different_winner when the recorded winner disagrees)
//   - multiple pair matches -> confidence 0.3, needs_review + ambiguous_match
//     conflict row
//   - zero pair matches -> confidence 0, needs_review. This can legitimately
//     happen when the source reports a match our bracket does not have (e.g. a
//     different consolation flow); an admin can still force-match manually.
// overall_confidence = extraction*0.4 + identity*0.35 + match*0.25 (2dp).
// Auto-approval: when the source policy is auto_all, or auto_high_confidence
// with overall >= the source threshold, and the match is a clean single
// pending pairing with no conflict, approve_candidate runs with auto=true.
// Match a normalized candidate to its internal bracket_match
function match_candidate {
  input {
    // external_result_candidate.id to match
    int candidate_id
  }

  stack {
    db.get external_result_candidate {
      field_name = "id"
      field_value = $input.candidate_id
    } as $candidate
  
    precondition ($candidate != null) {
      error_type = "notfound"
      error = "Candidate not found."
    }
  
    var $matchable_statuses {
      value = ["normalized", "needs_review"]
    }
  
    precondition ($matchable_statuses|some:$$ == $candidate.status) {
      error_type = "inputerror"
      error = "Candidate must be normalized or needs_review to match (current: " ~ $candidate.status ~ ")."
    }
  
    var $payload {
      value = $candidate.normalized_payload|first_notnull:{}
    }
  
    var $weight_class_id {
      value = $payload|get:"weight_class_id":null
    }
  
    var $winner_id {
      value = $payload|get:"winner_competitor_id":null
    }
  
    var $loser_id {
      value = $payload|get:"loser_competitor_id":null
    }
  
    var $match_confidence {
      value = 0
    }
  
    var $matched_match_id {
      value = null
    }
  
    var $new_status {
      value = "needs_review"
    }
  
    var $conflict_type {
      value = null
    }
  
    var $conflict_existing_value {
      value = null
    }
  
    var $conflict_candidate_value {
      value = null
    }
  
    var $conflict_match_id {
      value = null
    }
  
    conditional {
      if (($weight_class_id == null) || ($winner_id == null) || ($loser_id == null)) {
        // unresolved identity or weight class: nothing reliable to pair against
        var.update $match_confidence {
          value = 0
        }
      }
    
      else {
        db.query bracket_match {
          where = $db.bracket_match.weight_class_id == $weight_class_id
          return = {type: "list"}
        } as $wc_matches
      
        // pair in either slot order
        var $pair_matches {
          value = $wc_matches|filter:(($$.actual_top_wrestler_id == $winner_id && $$.actual_bottom_wrestler_id == $loser_id) || ($$.actual_top_wrestler_id == $loser_id && $$.actual_bottom_wrestler_id == $winner_id))
        }
      
        conditional {
          if (($pair_matches|count) == 1) {
            var $the_match {
              value = $pair_matches|first
            }
          
            var.update $matched_match_id {
              value = $the_match.id
            }
          
            conditional {
              if (($the_match.match_status == "pending") || ($the_match.match_status == "in_progress")) {
                var.update $match_confidence {
                  value = 1
                }
              
                var.update $new_status {
                  value = "matched"
                }
              }
            
              else {
                // the match already has an official result: never silently overwrite
                var.update $match_confidence {
                  value = 0.85
                }
              
                var.update $new_status {
                  value = "conflict"
                }
              
                var.update $conflict_type {
                  value = "existing_result"
                }
              
                conditional {
                  if (($the_match.actual_winner_wrestler_id != null) && ($the_match.actual_winner_wrestler_id != $winner_id)) {
                    var.update $conflict_type {
                      value = "different_winner"
                    }
                  }
                }
              
                var.update $conflict_match_id {
                  value = $the_match.id
                }
              
                var.update $conflict_existing_value {
                  value = {
                    winner_wrestler_id: $the_match.actual_winner_wrestler_id
                    loser_wrestler_id : $the_match.actual_loser_wrestler_id
                    victory_type      : $the_match.victory_type
                    score             : $the_match.actual_score
                    match_status      : $the_match.match_status
                  }
                }
              
                var.update $conflict_candidate_value {
                  value = {
                    winner_competitor_id: $winner_id
                    loser_competitor_id : $loser_id
                    victory_type        : $payload|get:"victory_type":null
                    score               : $payload|get:"score":null
                  }
                }
              }
            }
          }
        
          elseif (($pair_matches|count) > 1) {
            var.update $match_confidence {
              value = 0.3
            }
          
            var.update $new_status {
              value = "needs_review"
            }
          
            var.update $conflict_type {
              value = "ambiguous_match"
            }
          
            array.map ($pair_matches) {
              by = $this.id
            } as $pair_match_ids
          
            var.update $conflict_candidate_value {
              value = {
                match_ids           : $pair_match_ids
                winner_competitor_id: $winner_id
                loser_competitor_id : $loser_id
              }
            }
          }
        
          else {
            // zero pair matches: possibly a match our bracket does not have
            // (e.g. a different consolation flow) — admin can force-match manually
            var.update $match_confidence {
              value = 0
            }
          
            var.update $new_status {
              value = "needs_review"
            }
          }
        }
      }
    }
  
    // overall confidence: extraction 40%, identity 35%, match 25% (2dp)
    var $extraction_conf {
      value = $candidate.extraction_confidence|first_notnull:0
    }
  
    var $identity_conf {
      value = $candidate.identity_confidence|first_notnull:0
    }
  
    var $overall_raw {
      value = $extraction_conf * 0.4 + $identity_conf * 0.35 + $match_confidence * 0.25
    }
  
    var $overall_scaled {
      value = $overall_raw * 100
    }
  
    var $overall_confidence {
      value = ($overall_scaled|round) / 100
    }
  
    // Record the conflict row (deduped: one open row of a type per candidate)
    conditional {
      if ($conflict_type != null) {
        db.query ingestion_conflict {
          where = $db.ingestion_conflict.candidate_id == $candidate.id && $db.ingestion_conflict.conflict_type == $conflict_type && $db.ingestion_conflict.status == "open"
          return = {type: "list"}
        } as $existing_conflicts
      
        conditional {
          if (($existing_conflicts|count) == 0) {
            db.add ingestion_conflict {
              data = {
                tournament_id   : $candidate.tournament_id
                bracket_match_id: $conflict_match_id
                candidate_id    : $candidate.id
                conflict_type   : $conflict_type
                existing_value  : $conflict_existing_value
                candidate_value : $conflict_candidate_value
              }
            } as $conflict_row
          }
        }
      }
    }
  
    // Persist the match outcome first: approve_candidate reloads the row and
    // requires the stored status to be matched|needs_review|conflict
    db.edit external_result_candidate {
      field_name = "id"
      field_value = $candidate.id
      data = {
        matched_match_id  : $matched_match_id
        match_confidence  : $match_confidence
        overall_confidence: $overall_confidence
        status            : $new_status
      }
    } as $matched_candidate_row
  
    var $updated_candidate {
      value = $matched_candidate_row
    }
  
    // -----------------------------------------------------------------
    // Auto-approval: clean single pending match, no conflict, policy allows
    // -----------------------------------------------------------------
    conditional {
      if ($new_status == "matched") {
        db.get results_source_config {
          field_name = "id"
          field_value = $candidate.results_source_config_id
        } as $source_config
      
        var $auto_ok {
          value = false
        }
      
        conditional {
          if ($source_config != null) {
            var $threshold {
              value = $source_config.auto_approve_threshold|first_notnull:0.9
            }
          
            conditional {
              if ($source_config.approval_policy == "auto_all") {
                var.update $auto_ok {
                  value = true
                }
              }
            
              elseif (($source_config.approval_policy == "auto_high_confidence") && ($overall_confidence >= $threshold)) {
                var.update $auto_ok {
                  value = true
                }
              }
            }
          }
        }
      
        conditional {
          if ($auto_ok) {
            function.run approve_candidate {
              input = {candidate_id: $candidate.id, auto: true}
            } as $approve_result
          
            var.update $updated_candidate {
              value = $approve_result.candidate
            }
          }
        }
      }
    }
  }

  response = $updated_candidate
}
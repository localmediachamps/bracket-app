// Normalizes a raw external_result_candidate into internal identifiers
// (ingestion pipeline step 2: parsed -> normalized).
//   - Parses source_weight_class ("125 lbs", "125", "HWT") to an int weight and
//     finds the matching weight_class row for the candidate's tournament.
//   - Normalizes names (lower, punctuation stripped, spaces collapsed,
//     "Last, First" reordered) and maps source_victory_type text to the
//     bracket_match.victory_type enum (unknown text -> null + confidence cut).
//   - Resolves winner/loser identity against wrestlers in the weight class:
//     exact normalized-name match -> 1.0, unique last-name match -> 0.6,
//     school disambiguation of a last-name tie -> 0.7, unresolved multiple
//     -> 0.2 (+ identity_uncertain conflict row), no match -> 0.
//     A school substring cross-check (either direction) adds +0.15 (cap 1.0).
//   - Stores normalized_payload {weight_class_id, winner_competitor_id,
//     loser_competitor_id, victory_type, score} and sets identity_confidence.
// Status becomes "normalized", or "needs_review" when identity < 0.5 or the
// weight class could not be found.
// Normalize one external result candidate into internal ids and an enum result
function normalize_candidate {
  input {
    // external_result_candidate.id to normalize
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
  
    // Source config is loaded for context only; it may have been deleted while
    // candidates were kept as history, so a missing config is tolerated.
    db.get results_source_config {
      field_name = "id"
      field_value = $candidate.results_source_config_id
    } as $source_config
  
    db.get tournament {
      field_name = "id"
      field_value = $candidate.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found for candidate."
    }
  
    // -----------------------------------------------------------------
    // Weight class resolution
    // -----------------------------------------------------------------
    var $weight_text {
      value = $candidate.source_weight_class|first_notnull:""
    }
  
    var.update $weight_text {
      value = $weight_text|to_lower|trim
    }
  
    var $weight_int {
      value = 0
    }
  
    conditional {
      if (($weight_text|contains:"hwt") || ($weight_text|contains:"heavy")) {
        var.update $weight_int {
          value = 285
        }
      }
    
      else {
        var.update $weight_text {
          value = $weight_text|replace:"lbs":""
        }
      
        var.update $weight_text {
          value = $weight_text|replace:"lb":""
        }
      
        var.update $weight_text {
          value = $weight_text|replace:" ":""
        }
      
        var.update $weight_int {
          value = $weight_text|to_int
        }
      }
    }
  
    var $weight_class {
      value = null
    }
  
    var $weight_class_id {
      value = null
    }
  
    conditional {
      if ($weight_int > 0) {
        db.query weight_class {
          where = $db.weight_class.tournament_id == $candidate.tournament_id && $db.weight_class.weight == $weight_int
          return = {type: "single"}
        } as $wc
      
        var.update $weight_class {
          value = $wc
        }
      
        conditional {
          if ($wc != null) {
            var.update $weight_class_id {
              value = $wc.id
            }
          }
        }
      }
    }
  
    // -----------------------------------------------------------------
    // Name normalization helpers applied inline (winner, loser, schools)
    // -----------------------------------------------------------------
    var $winner_norm {
      value = $candidate.source_winner|first_notnull:""
    }
  
    var.update $winner_norm {
      value = $winner_norm|to_lower|trim
    }
  
    // Sources often report "Last, First" — reorder to "first last" so the
    // final token is always the last name
    conditional {
      if ($winner_norm|contains:",") {
        var $winner_comma_parts {
          value = $winner_norm|split:","
        }
      
        var $winner_first_name {
          value = $winner_comma_parts[1]|first_notnull:""
        }
      
        var $winner_last_name {
          value = $winner_comma_parts[0]|first_notnull:""
        }
      
        var.update $winner_norm {
          value = ($winner_first_name|trim) ~ " " ~ ($winner_last_name|trim)
        }
      }
    }
  
    var.update $winner_norm {
      value = "/[^a-z0-9 ]/"|regex_replace:"":$winner_norm
    }
  
    var.update $winner_norm {
      value = "/s+/"|regex_replace:" ":$winner_norm
    }
  
    var.update $winner_norm {
      value = $winner_norm|trim
    }
  
    var $loser_norm {
      value = $candidate.source_loser|first_notnull:""
    }
  
    var.update $loser_norm {
      value = $loser_norm|to_lower|trim
    }
  
    conditional {
      if ($loser_norm|contains:",") {
        var $loser_comma_parts {
          value = $loser_norm|split:","
        }
      
        var $loser_first_name {
          value = $loser_comma_parts[1]|first_notnull:""
        }
      
        var $loser_last_name {
          value = $loser_comma_parts[0]|first_notnull:""
        }
      
        var.update $loser_norm {
          value = ($loser_first_name|trim) ~ " " ~ ($loser_last_name|trim)
        }
      }
    }
  
    var.update $loser_norm {
      value = "/[^a-z0-9 ]/"|regex_replace:"":$loser_norm
    }
  
    var.update $loser_norm {
      value = "/s+/"|regex_replace:" ":$loser_norm
    }
  
    var.update $loser_norm {
      value = $loser_norm|trim
    }
  
    var $winner_school {
      value = $candidate.source_winner_school|first_notnull:""
    }
  
    var.update $winner_school {
      value = $winner_school|to_lower|trim
    }
  
    var.update $winner_school {
      value = "/[^a-z0-9 ]/"|regex_replace:"":$winner_school
    }
  
    var.update $winner_school {
      value = "/s+/"|regex_replace:" ":$winner_school
    }
  
    var.update $winner_school {
      value = $winner_school|trim
    }
  
    var $loser_school {
      value = $candidate.source_loser_school|first_notnull:""
    }
  
    var.update $loser_school {
      value = $loser_school|to_lower|trim
    }
  
    var.update $loser_school {
      value = "/[^a-z0-9 ]/"|regex_replace:"":$loser_school
    }
  
    var.update $loser_school {
      value = "/s+/"|regex_replace:" ":$loser_school
    }
  
    var.update $loser_school {
      value = $loser_school|trim
    }
  
    // -----------------------------------------------------------------
    // Victory type mapping (order matters: tech before fall, medical
    // before plain forfeit, injury before dq)
    // -----------------------------------------------------------------
    var $vt {
      value = $candidate.source_victory_type|first_notnull:""
    }
  
    var.update $vt {
      value = $vt|to_lower|trim
    }
  
    var.update $vt {
      value = $vt|replace:".":""
    }
  
    var $victory_type {
      value = null
    }
  
    var $victory_unknown {
      value = false
    }
  
    conditional {
      if (($vt|strlen) > 0) {
        conditional {
          if (($vt|contains:"mff") || (($vt|contains:"med") && ($vt|contains:"for"))) {
            var.update $victory_type {
              value = "medical_forfeit"
            }
          }
        
          elseif ($vt|contains:"inj") {
            var.update $victory_type {
              value = "injury_default"
            }
          }
        
          elseif (($vt|contains:"dq") || ($vt|contains:"disq")) {
            var.update $victory_type {
              value = "disqualification"
            }
          }
        
          elseif (($vt|contains:"fft") || ($vt|contains:"forfeit") || ($vt == "ff") || ($vt == "for")) {
            var.update $victory_type {
              value = "forfeit"
            }
          }
        
          elseif (($vt|contains:"tech") || ($vt|starts_with:"tf")) {
            var.update $victory_type {
              value = "tech_fall"
            }
          }
        
          elseif (($vt|contains:"fall") || ($vt|contains:"pin") || ($vt == "f") || ($vt|starts_with:"f ") || ($vt|starts_with:"f-")) {
            var.update $victory_type {
              value = "fall"
            }
          }
        
          elseif (($vt|contains:"maj") || ($vt|starts_with:"md")) {
            var.update $victory_type {
              value = "major"
            }
          }
        
          elseif (($vt|contains:"dec") || ($vt == "d")) {
            var.update $victory_type {
              value = "decision"
            }
          }
        
          else {
            // unrecognized victory text: keep null and cut confidence below
            var.update $victory_unknown {
              value = true
            }
          }
        }
      }
    }
  
    var $score_clean {
      value = $candidate.source_score
    }
  
    conditional {
      if ($score_clean != null) {
        var.update $score_clean {
          value = $score_clean|trim
        }
      }
    }
  
    // -----------------------------------------------------------------
    // Wrestler lookup for the weight class (uniformly normalized)
    // -----------------------------------------------------------------
    var $wlookup {
      value = []
    }
  
    conditional {
      if ($weight_class_id != null) {
        db.query wrestler {
          where = $db.wrestler.weight_class_id == $weight_class_id
          return = {type: "list"}
        } as $wrestlers
      
        foreach ($wrestlers) {
          each as $w {
            // prefer the stored normalized_name, fall back to the display name
            var $w_base {
              value = $w.normalized_name|first_notnull:""
            }
          
            conditional {
              if (($w_base|strlen) == 0) {
                var.update $w_base {
                  value = $w.name|first_notnull:""
                }
              }
            }
          
            var.update $w_base {
              value = $w_base|to_lower|trim
            }
          
            var.update $w_base {
              value = "/[^a-z0-9 ]/"|regex_replace:"":$w_base
            }
          
            var.update $w_base {
              value = "/s+/"|regex_replace:" ":$w_base
            }
          
            var.update $w_base {
              value = $w_base|trim
            }
          
            var $w_parts {
              value = $w_base|split:" "
            }
          
            var $w_last {
              value = $w_parts|last
            }
          
            var $w_school_norm {
              value = $w.school|first_notnull:""
            }
          
            var.update $w_school_norm {
              value = $w_school_norm|to_lower|trim
            }
          
            var.update $w_school_norm {
              value = "/[^a-z0-9 ]/"|regex_replace:"":$w_school_norm
            }
          
            var.update $w_school_norm {
              value = "/s+/"|regex_replace:" ":$w_school_norm
            }
          
            var.update $w_school_norm {
              value = $w_school_norm|trim
            }
          
            array.push $wlookup {
              value = {
                id         : $w.id
                name       : $w.name
                school     : $w.school
                norm       : $w_base
                last       : $w_last
                school_norm: $w_school_norm
              }
            }
          }
        }
      }
    }
  
    // -----------------------------------------------------------------
    // Winner identity: exact -> unique last-name -> school disambiguation
    // -----------------------------------------------------------------
    var $winner_id {
      value = null
    }
  
    var $winner_conf {
      value = 0
    }
  
    var $winner_ambiguous {
      value = false
    }
  
    var $winner_ambiguous_ids {
      value = []
    }
  
    conditional {
      if ((($winner_norm|strlen) > 0) && (($wlookup|count) > 0)) {
        var $winner_exact {
          value = $wlookup|filter:($$.norm == $winner_norm)
        }
      
        conditional {
          if (($winner_exact|count) == 1) {
            var.update $winner_id {
              value = ($winner_exact|first).id
            }
          
            var.update $winner_conf {
              value = 1
            }
          }
        
          else {
            var $winner_parts {
              value = $winner_norm|split:" "
            }
          
            var $winner_last {
              value = $winner_parts|last
            }
          
            var $winner_last_matches {
              value = []
            }
          
            conditional {
              if ($winner_last != null && (($winner_last|strlen) > 0)) {
                var.update $winner_last_matches {
                  value = $wlookup|filter:($$.last == $winner_last)
                }
              }
            }
          
            conditional {
              if (($winner_last_matches|count) == 1) {
                var.update $winner_id {
                  value = ($winner_last_matches|first).id
                }
              
                var.update $winner_conf {
                  value = 0.6
                }
              }
            
              elseif (($winner_last_matches|count) > 1) {
                // last-name tie: try narrowing by school substring either way
                var $winner_school_matches {
                  value = []
                }
              
                conditional {
                  if (($winner_school|strlen) > 0) {
                    var.update $winner_school_matches {
                      value = $winner_last_matches|filter:((($$.school_norm|strlen) > 0) && ((($$.school_norm|contains:$winner_school)) || (($winner_school|contains:$$.school_norm))))
                    }
                  }
                }
              
                conditional {
                  if (($winner_school_matches|count) == 1) {
                    var.update $winner_id {
                      value = ($winner_school_matches|first).id
                    }
                  
                    var.update $winner_conf {
                      value = 0.7
                    }
                  }
                
                  else {
                    var.update $winner_conf {
                      value = 0.2
                    }
                  
                    var.update $winner_ambiguous {
                      value = true
                    }
                  
                    array.map ($winner_last_matches) {
                      by = $this.id
                    } as $winner_amb_ids
                  
                    var.update $winner_ambiguous_ids {
                      value = $winner_amb_ids
                    }
                  }
                }
              }
            }
          }
        }
      
        // school cross-check boost on any resolved sub-1.0 identity
        conditional {
          if (($winner_id != null) && ($winner_conf < 1) && (($winner_school|strlen) > 0)) {
            var $winner_resolved {
              value = $wlookup|filter:($$.id == $winner_id)|first
            }
          
            conditional {
              if (($winner_resolved != null) && (($winner_resolved.school_norm|strlen) > 0)) {
                conditional {
                  if (($winner_resolved.school_norm|contains:$winner_school) || ($winner_school|contains:$winner_resolved.school_norm)) {
                    var.update $winner_conf {
                      value = ($winner_conf + 0.15)|min:1
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  
    // -----------------------------------------------------------------
    // Loser identity (same ladder as winner)
    // -----------------------------------------------------------------
    var $loser_id {
      value = null
    }
  
    var $loser_conf {
      value = 0
    }
  
    var $loser_ambiguous {
      value = false
    }
  
    var $loser_ambiguous_ids {
      value = []
    }
  
    conditional {
      if ((($loser_norm|strlen) > 0) && (($wlookup|count) > 0)) {
        var $loser_exact {
          value = $wlookup|filter:($$.norm == $loser_norm)
        }
      
        conditional {
          if (($loser_exact|count) == 1) {
            var.update $loser_id {
              value = ($loser_exact|first).id
            }
          
            var.update $loser_conf {
              value = 1
            }
          }
        
          else {
            var $loser_parts {
              value = $loser_norm|split:" "
            }
          
            var $loser_last {
              value = $loser_parts|last
            }
          
            var $loser_last_matches {
              value = []
            }
          
            conditional {
              if ($loser_last != null && (($loser_last|strlen) > 0)) {
                var.update $loser_last_matches {
                  value = $wlookup|filter:($$.last == $loser_last)
                }
              }
            }
          
            conditional {
              if (($loser_last_matches|count) == 1) {
                var.update $loser_id {
                  value = ($loser_last_matches|first).id
                }
              
                var.update $loser_conf {
                  value = 0.6
                }
              }
            
              elseif (($loser_last_matches|count) > 1) {
                var $loser_school_matches {
                  value = []
                }
              
                conditional {
                  if (($loser_school|strlen) > 0) {
                    var.update $loser_school_matches {
                      value = $loser_last_matches|filter:((($$.school_norm|strlen) > 0) && ((($$.school_norm|contains:$loser_school)) || (($loser_school|contains:$$.school_norm))))
                    }
                  }
                }
              
                conditional {
                  if (($loser_school_matches|count) == 1) {
                    var.update $loser_id {
                      value = ($loser_school_matches|first).id
                    }
                  
                    var.update $loser_conf {
                      value = 0.7
                    }
                  }
                
                  else {
                    var.update $loser_conf {
                      value = 0.2
                    }
                  
                    var.update $loser_ambiguous {
                      value = true
                    }
                  
                    array.map ($loser_last_matches) {
                      by = $this.id
                    } as $loser_amb_ids
                  
                    var.update $loser_ambiguous_ids {
                      value = $loser_amb_ids
                    }
                  }
                }
              }
            }
          }
        }
      
        conditional {
          if (($loser_id != null) && ($loser_conf < 1) && (($loser_school|strlen) > 0)) {
            var $loser_resolved {
              value = $wlookup|filter:($$.id == $loser_id)|first
            }
          
            conditional {
              if (($loser_resolved != null) && (($loser_resolved.school_norm|strlen) > 0)) {
                conditional {
                  if (($loser_resolved.school_norm|contains:$loser_school) || ($loser_school|contains:$loser_resolved.school_norm)) {
                    var.update $loser_conf {
                      value = ($loser_conf + 0.15)|min:1
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  
    // identity_confidence is the weaker of the two resolutions
    var $identity_confidence {
      value = $winner_conf|min:$loser_conf
    }
  
    conditional {
      if ($victory_unknown) {
        var.update $identity_confidence {
          value = ($identity_confidence - 0.1)|max:0
        }
      }
    }
  
    // -----------------------------------------------------------------
    // identity_uncertain conflict row (deduped: one open row per candidate)
    // -----------------------------------------------------------------
    conditional {
      if ($winner_ambiguous || $loser_ambiguous) {
        db.query ingestion_conflict {
          where = $db.ingestion_conflict.candidate_id == $candidate.id && $db.ingestion_conflict.conflict_type == "identity_uncertain" && $db.ingestion_conflict.status == "open"
          return = {type: "list"}
        } as $existing_identity_conflicts
      
        conditional {
          if (($existing_identity_conflicts|count) == 0) {
            db.add ingestion_conflict {
              data = {
                tournament_id  : $candidate.tournament_id
                candidate_id   : $candidate.id
                conflict_type  : "identity_uncertain"
                existing_value : null
                candidate_value: {
                winner: {
                source_name  : $candidate.source_winner
                candidate_ids: $winner_ambiguous_ids
                confidence   : $winner_conf
              }
                loser : {
                source_name  : $candidate.source_loser
                candidate_ids: $loser_ambiguous_ids
                confidence   : $loser_conf
              }
              }
              }
            } as $identity_conflict_row
          }
        }
      }
    }
  
    // -----------------------------------------------------------------
    // Persist the normalized payload
    // -----------------------------------------------------------------
    var $normalized_payload {
      value = {
        weight_class_id     : $weight_class_id
        winner_competitor_id: $winner_id
        loser_competitor_id : $loser_id
        victory_type        : $victory_type
        score               : $score_clean
      }
    }
  
    var $new_status {
      value = "normalized"
    }
  
    conditional {
      if (($weight_class_id == null) || ($identity_confidence < 0.5)) {
        var.update $new_status {
          value = "needs_review"
        }
      }
    }
  
    db.edit external_result_candidate {
      field_name = "id"
      field_value = $candidate.id
      data = {
        normalized_payload : $normalized_payload
        identity_confidence: $identity_confidence
        status             : $new_status
      }
    } as $updated_candidate
  }

  response = $updated_candidate
}
// Validates the bracket_match graph for one weight class.
// Runs after every bracket_generate and returns {valid, issues}.
// Checks (ARCHITECTURE.md section 3 self-check):
//   - exactly one champ_finals match
//   - every non-final / non-placement match has a winner destination
//   - no destination slot is fed by more than one routing edge
//   - routing edges agree with the destination slot's source fields
//   - no circular references (bounded ancestor walk, max depth 40)
//   - every seed 1..C appears exactly once as a seed-sourced slot
//   - bye matches are stored complete
//   - placement matches exist (place_3 always; place_5/place_7 in full consolation)
//   - total match count matches the template expectation when derivable
// Validate the match graph of a generated bracket; returns {valid, issues}
function bracket_self_check {
  input {
    // Weight class whose bracket should be validated
    int weight_class_id
  }

  stack {
    db.query bracket_match {
      where = $db.bracket_match.weight_class_id == $input.weight_class_id
      sort = {display_order: "asc"}
      return = {type: "list"}
    } as $matches
  
    db.get weight_class {
      field_name = "id"
      field_value = $input.weight_class_id
    } as $wc
  
    db.query wrestler {
      where = $db.wrestler.weight_class_id == $input.weight_class_id
      sort = {seed: "asc"}
      return = {type: "list"}
      output = ["id", "seed", "name"]
    } as $wrestlers
  
    var $issues {
      value = []
    }
  
    var $match_count {
      value = $matches|count
    }
  
    var $competitor_count {
      value = $wrestlers|count
    }
  
    // Lookup map: match id -> match row
    var $match_map {
      value = {}
    }
  
    foreach ($matches) {
      each as $m {
        var.update $match_map {
          value = $match_map|set:$m.id:$m
        }
      }
    }
  
    // ------------------------------------------------------------------
    // CHECK: exactly one championship final
    // ------------------------------------------------------------------
    var $finals_count {
      value = 0
    }
  
    var $place3_count {
      value = 0
    }
  
    var $place5_count {
      value = 0
    }
  
    var $place7_count {
      value = 0
    }
  
    foreach ($matches) {
      each as $m {
        conditional {
          if ($m.round_code == "champ_finals") {
            var.update $finals_count {
              value = $finals_count + 1
            }
          }
        }
      
        conditional {
          if ($m.round_code == "place_3") {
            var.update $place3_count {
              value = $place3_count + 1
            }
          }
        }
      
        conditional {
          if ($m.round_code == "place_5") {
            var.update $place5_count {
              value = $place5_count + 1
            }
          }
        }
      
        conditional {
          if ($m.round_code == "place_7") {
            var.update $place7_count {
              value = $place7_count + 1
            }
          }
        }
      }
    }
  
    conditional {
      if ($finals_count != 1) {
        array.push $issues {
          value = {
            severity: "error"
            code    : "FINALS_COUNT"
            message : "Expected exactly 1 champ_finals match, found " ~ $finals_count ~ "."
          }
        }
      }
    }
  
    // ------------------------------------------------------------------
    // CHECK: routing completeness, double-sourcing, source agreement
    // ------------------------------------------------------------------
    var $slot_refs {
      value = {}
    }
  
    foreach ($matches) {
      each as $m {
        // Every match except the championship final and placement matches
        // must route its winner onward.
        conditional {
          if ($m.round_code != "champ_finals" && $m.bracket_section != "placement") {
            conditional {
              if ($m.winner_advances_to_match_id == null) {
                array.push $issues {
                  value = {
                    severity: "error"
                    code    : "MISSING_WINNER_DEST"
                    message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " has no winner_advances_to_match_id."
                    match_id: $m.id
                  }
                }
              }
            }
          }
        }
      
        // Bye matches must be stored as complete
        conditional {
          if ($m.is_bye && $m.match_status != "complete") {
            array.push $issues {
              value = {
                severity: "error"
                code    : "BYE_NOT_COMPLETE"
                message : "Bye match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " is not marked complete."
                match_id: $m.id
              }
            }
          }
        }
      
        // Winner routing edge: uniqueness + agreement with destination slot source
        conditional {
          if ($m.winner_advances_to_match_id != null) {
            var $wslot {
              value = $m.winner_slot_in_next|first_notnull:"?"
            }
          
            var $wref {
              value = $m.winner_advances_to_match_id ~ "|" ~ $wslot
            }
          
            var $wref_count {
              value = ($slot_refs|get:$wref:0) + 1
            }
          
            var.update $slot_refs {
              value = $slot_refs|set:$wref:$wref_count
            }
          
            conditional {
              if ($wref_count > 1) {
                array.push $issues {
                  value = {
                    severity: "error"
                    code    : "SLOT_DOUBLE_SOURCED"
                    message : "Destination slot " ~ $wref ~ " is fed by more than one routing edge."
                    match_id: $m.id
                  }
                }
              }
            }
          
            var $wdest {
              value = $match_map[$m.winner_advances_to_match_id]
            }
          
            conditional {
              if ($wdest == null) {
                array.push $issues {
                  value = {
                    severity: "error"
                    code    : "ROUTING_TARGET_MISSING"
                    message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " routes its winner to a non-existent match."
                    match_id: $m.id
                  }
                }
              }
            
              else {
                conditional {
                  if ($wslot == "top") {
                    conditional {
                      if ($wdest.top_source_type != "match_winner" || $wdest.top_source_match_id != $m.id) {
                        array.push $issues {
                          value = {
                            severity: "error"
                            code    : "ROUTING_SOURCE_MISMATCH"
                            message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " winner routes to match " ~ $wdest.id ~ " top, but that slot's source fields disagree."
                            match_id: $m.id
                          }
                        }
                      }
                    }
                  }
                
                  elseif ($wslot == "bottom") {
                    conditional {
                      if ($wdest.bottom_source_type != "match_winner" || $wdest.bottom_source_match_id != $m.id) {
                        array.push $issues {
                          value = {
                            severity: "error"
                            code    : "ROUTING_SOURCE_MISMATCH"
                            message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " winner routes to match " ~ $wdest.id ~ " bottom, but that slot's source fields disagree."
                            match_id: $m.id
                          }
                        }
                      }
                    }
                  }
                
                  else {
                    array.push $issues {
                      value = {
                        severity: "error"
                        code    : "ROUTING_SLOT_INVALID"
                        message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " has an invalid winner_slot_in_next."
                        match_id: $m.id
                      }
                    }
                  }
                }
              }
            }
          }
        }
      
        // Loser routing edge: uniqueness + agreement with destination slot source
        conditional {
          if ($m.loser_drops_to_match_id != null) {
            var $lslot {
              value = $m.loser_slot_in_next|first_notnull:"?"
            }
          
            var $lref {
              value = $m.loser_drops_to_match_id ~ "|" ~ $lslot
            }
          
            var $lref_count {
              value = ($slot_refs|get:$lref:0) + 1
            }
          
            var.update $slot_refs {
              value = $slot_refs|set:$lref:$lref_count
            }
          
            conditional {
              if ($lref_count > 1) {
                array.push $issues {
                  value = {
                    severity: "error"
                    code    : "SLOT_DOUBLE_SOURCED"
                    message : "Destination slot " ~ $lref ~ " is fed by more than one routing edge."
                    match_id: $m.id
                  }
                }
              }
            }
          
            var $ldest {
              value = $match_map[$m.loser_drops_to_match_id]
            }
          
            conditional {
              if ($ldest == null) {
                array.push $issues {
                  value = {
                    severity: "error"
                    code    : "ROUTING_TARGET_MISSING"
                    message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " routes its loser to a non-existent match."
                    match_id: $m.id
                  }
                }
              }
            
              else {
                conditional {
                  if ($lslot == "top") {
                    conditional {
                      if ($ldest.top_source_type != "match_loser" || $ldest.top_source_match_id != $m.id) {
                        array.push $issues {
                          value = {
                            severity: "error"
                            code    : "ROUTING_SOURCE_MISMATCH"
                            message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " loser routes to match " ~ $ldest.id ~ " top, but that slot's source fields disagree."
                            match_id: $m.id
                          }
                        }
                      }
                    }
                  }
                
                  elseif ($lslot == "bottom") {
                    conditional {
                      if ($ldest.bottom_source_type != "match_loser" || $ldest.bottom_source_match_id != $m.id) {
                        array.push $issues {
                          value = {
                            severity: "error"
                            code    : "ROUTING_SOURCE_MISMATCH"
                            message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " loser routes to match " ~ $ldest.id ~ " bottom, but that slot's source fields disagree."
                            match_id: $m.id
                          }
                        }
                      }
                    }
                  }
                
                  else {
                    array.push $issues {
                      value = {
                        severity: "error"
                        code    : "ROUTING_SLOT_INVALID"
                        message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " has an invalid loser_slot_in_next."
                        match_id: $m.id
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
  
    // ------------------------------------------------------------------
    // CHECK: circular references (bounded ancestor walk, max depth 40)
    // A path longer than 40 edges or a runaway walk means a cycle.
    // ------------------------------------------------------------------
    foreach ($matches) {
      each as $m {
        var $walk_stack {
          value = []
        }
      
        array.push $walk_stack {
          value = {id: $m.id, d: 0}
        }
      
        var $steps {
          value = 0
        }
      
        var $cycle_found {
          value = false
        }
      
        while ((($walk_stack|count) > 0) && ($steps < 1000) && ($cycle_found == false)) {
          each {
            array.pop $walk_stack as $node
            var.update $steps {
              value = $steps + 1
            }
          
            conditional {
              if ($node.d > 40) {
                array.push $issues {
                  value = {
                    severity: "error"
                    code    : "CIRCULAR_REF"
                    message : "Ancestor walk from match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " exceeded 40 levels; circular reference suspected."
                    match_id: $m.id
                  }
                }
              
                var.update $cycle_found {
                  value = true
                }
              }
            
              else {
                var $node_match {
                  value = $match_map[$node.id]
                }
              
                conditional {
                  if ($node_match != null) {
                    conditional {
                      if ($node_match.top_source_match_id != null) {
                        array.push $walk_stack {
                          value = {id: $node_match.top_source_match_id, d: $node.d + 1}
                        }
                      }
                    }
                  
                    conditional {
                      if ($node_match.bottom_source_match_id != null) {
                        array.push $walk_stack {
                          value = {id: $node_match.bottom_source_match_id, d: $node.d + 1}
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      
        conditional {
          if ($steps >= 1000) {
            array.push $issues {
              value = {
                severity: "error"
                code    : "CIRCULAR_REF"
                message : "Ancestor walk from match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " did not terminate; circular reference suspected."
                match_id: $m.id
              }
            }
          }
        }
      }
    }
  
    // ------------------------------------------------------------------
    // CHECK: every seed 1..C appears exactly once as a seed-sourced slot
    // ------------------------------------------------------------------
    var $seed_usage {
      value = {}
    }
  
    foreach ($matches) {
      each as $m {
        conditional {
          if ($m.top_source_type == "seed" && $m.top_source_seed != null) {
            var $tseed_key {
              value = $m.top_source_seed ~ ""
            }
          
            var $tseed_count {
              value = ($seed_usage|get:$tseed_key:0) + 1
            }
          
            var.update $seed_usage {
              value = $seed_usage|set:$tseed_key:$tseed_count
            }
          }
        }
      
        conditional {
          if ($m.bottom_source_type == "seed" && $m.bottom_source_seed != null) {
            var $bseed_key {
              value = $m.bottom_source_seed ~ ""
            }
          
            var $bseed_count {
              value = ($seed_usage|get:$bseed_key:0) + 1
            }
          
            var.update $seed_usage {
              value = $seed_usage|set:$bseed_key:$bseed_count
            }
          }
        }
      }
    }
  
    foreach ($wrestlers) {
      each as $w {
        var $wseed_key {
          value = $w.seed ~ ""
        }
      
        var $wseed_count {
          value = $seed_usage|get:$wseed_key:0
        }
      
        conditional {
          if ($wseed_count == 0) {
            array.push $issues {
              value = {
                severity: "error"
                code    : "SEED_MISSING"
                message : "Seed " ~ $w.seed ~ " (" ~ $w.name ~ ") never appears as an initial participant."
              }
            }
          }
        
          elseif ($wseed_count > 1) {
            array.push $issues {
              value = {
                severity: "error"
                code    : "SEED_DUPLICATE"
                message : "Seed " ~ $w.seed ~ " (" ~ $w.name ~ ") appears " ~ $wseed_count ~ " times as an initial participant."
              }
            }
          }
        }
      }
    }
  
    // Seeds referenced that have no wrestler row
    foreach ($matches) {
      each as $m {
        conditional {
          if ($m.top_source_type == "seed" && $m.top_source_seed != null && ($m.top_source_seed > $competitor_count)) {
            array.push $issues {
              value = {
                severity: "warning"
                code    : "SEED_UNKNOWN"
                message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " references seed " ~ $m.top_source_seed ~ " which has no wrestler (bye slot)."
                match_id: $m.id
              }
            }
          }
        }
      
        conditional {
          if ($m.bottom_source_type == "seed" && $m.bottom_source_seed != null && ($m.bottom_source_seed > $competitor_count)) {
            array.push $issues {
              value = {
                severity: "warning"
                code    : "SEED_UNKNOWN"
                message : "Match " ~ $m.round_code ~ " #" ~ $m.match_number ~ " references seed " ~ $m.bottom_source_seed ~ " which has no wrestler (bye slot)."
                match_id: $m.id
              }
            }
          }
        }
      }
    }
  
    // ------------------------------------------------------------------
    // CHECK: placement matches
    // ------------------------------------------------------------------
    conditional {
      if ($place3_count != 1) {
        array.push $issues {
          value = {
            severity: "error"
            code    : "PLACEMENT_MISSING"
            message : "Expected exactly 1 place_3 match, found " ~ $place3_count ~ "."
          }
        }
      }
    }
  
    // Full consolation inferred from the presence of 5th/7th place matches
    var $has_full_consolation {
      value = ($place5_count > 0) || ($place7_count > 0)
    }
  
    conditional {
      if ($has_full_consolation) {
        conditional {
          if ($place5_count != 1 || $place7_count != 1) {
            array.push $issues {
              value = {
                severity: "error"
                code    : "PLACEMENT_MISSING"
                message : "Full consolation requires exactly 1 place_5 and 1 place_7 match; found " ~ $place5_count ~ " and " ~ $place7_count ~ "."
              }
            }
          }
        }
      }
    }
  
    conditional {
      if ($wc != null && $wc.bracket_template == "ncaa_33" && ($has_full_consolation == false)) {
        array.push $issues {
          value = {
            severity: "error"
            code    : "PLACEMENT_MISSING"
            message : "Template ncaa_33 requires full consolation placements (place_5, place_7)."
          }
        }
      }
    }
  
    // ------------------------------------------------------------------
    // CHECK: expected match count (when template parameters are derivable)
    // ------------------------------------------------------------------
    conditional {
      if ($wc != null && $wc.bracket_size != null && $competitor_count > 0) {
        var $n_size {
          value = $wc.bracket_size
        }
      
        var $k_rounds {
          value = 0
        }
      
        conditional {
          if ($n_size == 4) {
            var.update $k_rounds {
              value = 2
            }
          }
        
          elseif ($n_size == 8) {
            var.update $k_rounds {
              value = 3
            }
          }
        
          elseif ($n_size == 16) {
            var.update $k_rounds {
              value = 4
            }
          }
        
          elseif ($n_size == 32) {
            var.update $k_rounds {
              value = 5
            }
          }
        
          elseif ($n_size == 64) {
            var.update $k_rounds {
              value = 6
            }
          }
        }
      
        var $pigtail_count {
          value = 0
        }
      
        conditional {
          if ($competitor_count > $n_size) {
            var.update $pigtail_count {
              value = $competitor_count - $n_size
            }
          }
        }
      
        // Consolation match expectation for full consolation by size
        var $cons_expected {
          value = 0
        }
      
        conditional {
          if ($k_rounds == 3) {
            var.update $cons_expected {
              value = 3
            }
          }
        
          elseif ($k_rounds >= 4) {
            // cons_r1 + cons_r2 (N/4 each) plus the final cons round (2)
            var.update $cons_expected {
              value = ($n_size / 2) + 2
            }
          
            // Intermediate staggered rounds for champ rounds k = 3..K-2
            var $stagger_rounds {
              value = $k_rounds - 4
            }
          
            conditional {
              if ($stagger_rounds > 0) {
                for ($stagger_rounds) {
                  each as $sidx {
                    var $s_k {
                      value = $sidx + 3
                    }
                  
                    var $s_size {
                      value = ($n_size / (2|pow:$s_k))|to_int
                    }
                  
                    var.update $cons_expected {
                      value = $cons_expected + (2 * $s_size)
                    }
                  }
                }
              }
            }
          }
        }
      
        var $expected_total {
          value = ($n_size - 1) + $pigtail_count + 1
        }
      
        conditional {
          if ($has_full_consolation) {
            var.update $expected_total {
              value = (($n_size - 1) + $pigtail_count) + $cons_expected + 3
            }
          }
        }
      
        conditional {
          if ($expected_total != $match_count) {
            array.push $issues {
              value = {
                severity: "error"
                code    : "MATCH_COUNT_MISMATCH"
                message : "Expected " ~ $expected_total ~ " matches for this template, found " ~ $match_count ~ "."
              }
            }
          }
        }
      }
    }
  
    // valid = no error-severity issues
    var $error_count {
      value = 0
    }
  
    foreach ($issues) {
      each as $issue {
        conditional {
          if ($issue.severity == "error") {
            var.update $error_count {
              value = $error_count + 1
            }
          }
        }
      }
    }
  
    var $result {
      value = {valid: $error_count == 0, issues: $issues}
    }
  }

  response = $result
}
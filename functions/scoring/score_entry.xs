// Scores a single user_bracket entry against current match results (ARCHITECTURE.md section 5).
// Idempotent and deterministic: re-running yields identical totals.
// Refreshes every pick's points_available from the tournament scoring_config,
// resolves outcome_status (pending|correct|incorrect|eliminated|void), then
// recomputes entry aggregates: total_points, possible_points, pick counts,
// champions_correct, finalists_correct, scoring_version.
// Score one bracket entry: resolve every pick outcome and recompute entry aggregates
function score_entry {
  input {
    // The user_bracket entry to score
    int user_bracket_id
  }

  stack {
    db.get user_bracket {
      field_name = "id"
      field_value = $input.user_bracket_id
    } as $entry
  
    precondition ($entry != null) {
      error_type = "notfound"
      error = "Entry not found."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $entry.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    // Resolve scoring config, falling back to defaults
    var $scoring_config {
      value = $tournament.scoring_config
    }
  
    conditional {
      if ($scoring_config == null) {
        function.run get_default_scoring_config as $default_config
        var.update $scoring_config {
          value = $default_config
        }
      }
    }
  
    var $scoring_version {
      value = $scoring_config|get:"version":1
    }
  
    var $bracket_cfg {
      value = $scoring_config|get:"bracket":{}
    }
  
    // All picks on this entry
    db.query user_pick {
      where = $db.user_pick.user_bracket_id == $input.user_bracket_id
      return = {type: "list"}
    } as $picks
  
    // All matches in the tournament, indexed by id for lookup and the ancestor walk
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $entry.tournament_id
      return = {type: "list"}
    } as $all_matches
  
    var $match_by_id {
      value = {}
    }
  
    foreach ($all_matches) {
      each as $m {
        var.update $match_by_id {
          value = $match_by_id|set:$m.id:$m
        }
      }
    }
  
    // Aggregate accumulators
    var $total_points {
      value = 0
    }
  
    var $possible_points {
      value = 0
    }
  
    var $correct_count {
      value = 0
    }
  
    var $scored_count {
      value = 0
    }
  
    var $champions_correct {
      value = 0
    }
  
    var $finalists_correct {
      value = 0
    }
  
    var $picks_updated {
      value = 0
    }
  
    foreach ($picks) {
      each as $pick {
        var $match {
          value = $match_by_id[$pick.bracket_match_id]
        }
      
        // points_available lookup, always refreshed from the current config
        var $points_available {
          value = null
        }
      
        conditional {
          if ($match != null) {
            conditional {
              if ($match.round_code == "pigtail") {
                var.update $points_available {
                  value = $bracket_cfg|get:"pigtail":null
                }
              }
            
              elseif ($match.bracket_section == "placement") {
                var $placement_map {
                  value = $bracket_cfg|get:"placement":{}
                }
              
                conditional {
                  if ($placement_map|has:$match.round_code) {
                    var.update $points_available {
                      value = $placement_map[$match.round_code]
                    }
                  }
                }
              }
            
              else {
                var $section_map {
                  value = null
                }
              
                conditional {
                  if ($bracket_cfg|has:$match.bracket_section) {
                    var.update $section_map {
                      value = $bracket_cfg[$match.bracket_section]
                    }
                  }
                }
              
                conditional {
                  if ($section_map != null) {
                    var $round_key {
                      value = $match.round_number|to_text
                    }
                  
                    conditional {
                      if ($section_map|has:$round_key) {
                        var.update $points_available {
                          value = $section_map[$round_key]
                        }
                      }
                    }
                  
                    // fallback: nearest defined lower round_number
                    conditional {
                      if ($points_available == null) {
                        var $best_lower {
                          value = 0
                        }
                      
                        var $section_keys {
                          value = $section_map|keys
                        }
                      
                        foreach ($section_keys) {
                          each as $skey {
                            var $skey_int {
                              value = $skey|to_int
                            }
                          
                            conditional {
                              if ($skey_int <= $match.round_number && $skey_int > $best_lower) {
                                var.update $best_lower {
                                  value = $skey_int
                                }
                              }
                            }
                          }
                        }
                      
                        conditional {
                          if ($best_lower > 0) {
                            var $lower_key {
                              value = $best_lower|to_text
                            }
                          
                            conditional {
                              if ($section_map|has:$lower_key) {
                                var.update $points_available {
                                  value = $section_map[$lower_key]
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
            }
          }
        }
      
        conditional {
          if ($points_available == null) {
            var.update $points_available {
              value = 1
            }
          }
        }
      
        // outcome resolution
        var $new_outcome {
          value = "pending"
        }
      
        var $new_earned {
          value = 0
        }
      
        var $new_is_correct {
          value = null
        }
      
        conditional {
          if ($match == null) {
            // defensive: pick references a missing match
            var.update $new_outcome {
              value = "void"
            }
          }
        
          elseif ($match.is_bye) {
            // byes are displayed, not predicted
            var.update $new_outcome {
              value = "void"
            }
          }
        
          elseif ($match.match_status == "cancelled") {
            var.update $new_outcome {
              value = "void"
            }
          }
        
          elseif ($match.match_status == "complete" || $match.match_status == "corrected") {
            math.add $scored_count {
              value = 1
            }
          
            conditional {
              if ($match.actual_winner_wrestler_id != null && $pick.picked_wrestler_id == $match.actual_winner_wrestler_id) {
                var.update $new_outcome {
                  value = "correct"
                }
              
                var.update $new_earned {
                  value = $points_available
                }
              
                var.update $new_is_correct {
                  value = true
                }
              
                math.add $total_points {
                  value = $points_available
                }
              
                math.add $correct_count {
                  value = 1
                }
              }
            
              else {
                var.update $new_outcome {
                  value = "incorrect"
                }
              
                var.update $new_is_correct {
                  value = false
                }
              }
            }
          
            // champ_finals tiebreak stats
            conditional {
              if ($match.round_code == "champ_finals") {
                conditional {
                  if ($new_outcome == "correct") {
                    math.add $champions_correct {
                      value = 1
                    }
                  }
                }
              
                conditional {
                  if ($pick.picked_wrestler_id == $match.actual_top_wrestler_id || $pick.picked_wrestler_id == $match.actual_bottom_wrestler_id) {
                    math.add $finalists_correct {
                      value = 1
                    }
                  }
                }
              }
            }
          }
        
          else {
            // pending / in_progress: elimination (reachability) check
            var $is_reachable {
              value = false
            }
          
            conditional {
              if ($pick.picked_wrestler_id == $match.actual_top_wrestler_id || $pick.picked_wrestler_id == $match.actual_bottom_wrestler_id) {
                var.update $is_reachable {
                  value = true
                }
              }
            
              else {
                // walk the ancestor closure via slot-source matches, depth capped at 40
                var $queue {
                  value = []
                }
              
                conditional {
                  if ($match.top_source_match_id != null) {
                    array.push $queue {
                      value = {id: $match.top_source_match_id, depth: 1}
                    }
                  }
                }
              
                conditional {
                  if ($match.bottom_source_match_id != null) {
                    array.push $queue {
                      value = {id: $match.bottom_source_match_id, depth: 1}
                    }
                  }
                }
              
                var $visited {
                  value = {}
                }
              
                while ((($queue|count) > 0) && ($is_reachable == false)) {
                  each {
                    array.shift $queue as $node
                    var $node_key {
                      value = $node.id|to_text
                    }
                  
                    conditional {
                      if (($visited|has:$node_key) == false && $node.depth <= 40) {
                        var.update $visited {
                          value = $visited|set:$node_key:true
                        }
                      
                        var $ancestor {
                          value = $match_by_id[$node.id]
                        }
                      
                        conditional {
                          if ($ancestor != null) {
                            // only an uncompleted ancestor can still deliver the wrestler here;
                            // a wrestler who already lost elsewhere no longer appears in any
                            // uncompleted ancestor on the path to this match
                            conditional {
                              if ($ancestor.match_status == "pending" || $ancestor.match_status == "in_progress") {
                                conditional {
                                  if ($pick.picked_wrestler_id == $ancestor.actual_top_wrestler_id || $pick.picked_wrestler_id == $ancestor.actual_bottom_wrestler_id) {
                                    var.update $is_reachable {
                                      value = true
                                    }
                                  }
                                }
                              }
                            }
                          
                            var $next_depth {
                              value = $node.depth + 1
                            }
                          
                            conditional {
                              if ($ancestor.top_source_match_id != null) {
                                array.push $queue {
                                  value = {id: $ancestor.top_source_match_id, depth: $next_depth}
                                }
                              }
                            }
                          
                            conditional {
                              if ($ancestor.bottom_source_match_id != null) {
                                array.push $queue {
                                  value = {id: $ancestor.bottom_source_match_id, depth: $next_depth}
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
            }
          
            conditional {
              if ($is_reachable) {
                // still alive: remains pending and contributes to possible_points
                math.add $possible_points {
                  value = $points_available
                }
              }
            
              else {
                var.update $new_outcome {
                  value = "eliminated"
                }
              
                var.update $new_is_correct {
                  value = false
                }
              }
            }
          }
        }
      
        // persist the pick only when something changed
        var $pick_changed {
          value = false
        }
      
        conditional {
          if ($pick.outcome_status != $new_outcome) {
            var.update $pick_changed {
              value = true
            }
          }
        }
      
        conditional {
          if ($pick.is_correct != $new_is_correct) {
            var.update $pick_changed {
              value = true
            }
          }
        }
      
        conditional {
          if ($pick.points_available != $points_available) {
            var.update $pick_changed {
              value = true
            }
          }
        }
      
        var $stored_earned {
          value = $pick.points_earned|first_notnull:0
        }
      
        conditional {
          if ($stored_earned != $new_earned) {
            var.update $pick_changed {
              value = true
            }
          }
        }
      
        conditional {
          if ($pick_changed) {
            db.edit user_pick {
              field_name = "id"
              field_value = $pick.id
              data = {
                outcome_status  : $new_outcome
                points_earned   : $new_earned
                points_available: $points_available
                is_correct      : $new_is_correct
                updated_at      : "now"
              }
            } as $updated_pick
          
            math.add $picks_updated {
              value = 1
            }
          }
        }
      }
    }
  
    // entry aggregates
    db.edit user_bracket {
      field_name = "id"
      field_value = $input.user_bracket_id
      data = {
        total_points      : $total_points
        possible_points   : $possible_points
        correct_pick_count: $correct_count
        scored_pick_count : $scored_count
        champions_correct : $champions_correct
        finalists_correct : $finalists_correct
        scoring_version   : $scoring_version
        updated_at        : "now"
      }
    } as $updated_entry
  }

  response = {
    user_bracket_id   : $input.user_bracket_id
    total_points      : $total_points
    possible_points   : $possible_points
    correct_pick_count: $correct_count
    scored_pick_count : $scored_count
    champions_correct : $champions_correct
    finalists_correct : $finalists_correct
    scoring_version   : $scoring_version
    picks_updated     : $picks_updated
  }
}
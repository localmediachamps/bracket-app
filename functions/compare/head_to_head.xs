// Head-to-head comparison of two bracket entries (ARCHITECTURE.md section 8:
// GET /entries/{a}/compare/{b}).
// common_picks = matches both predicted with the same wrestler.
// differing_picks = matches both predicted with different wrestlers.
// a_correct / b_correct = correct picks among matches BOTH entries predicted.
// decisive_matches = pending/in-progress matches where picks differ and at least
// one side's wrestler is still a participant in the match (can still score).
// champions = per-side map of weight value -> picked champion name (champ_finals picks).
// Compare two bracket entries pick-by-pick per ARCHITECTURE.md section 8
function head_to_head {
  input {
    // First user_bracket entry id
    int entry_id_a
  
    // Second user_bracket entry id
    int entry_id_b
  }

  stack {
    db.get user_bracket {
      field_name = "id"
      field_value = $input.entry_id_a
    } as $entry_a
  
    precondition ($entry_a != null) {
      error_type = "notfound"
      error = "Entry A not found"
    }
  
    db.get user_bracket {
      field_name = "id"
      field_value = $input.entry_id_b
    } as $entry_b
  
    precondition ($entry_b != null) {
      error_type = "notfound"
      error = "Entry B not found"
    }
  
    precondition ($entry_a.tournament_id == $entry_b.tournament_id) {
      error_type = "inputerror"
      error = "Entries belong to different tournaments"
    }
  
    db.get user {
      field_name = "id"
      field_value = $entry_a.user_id
    } as $user_a
  
    db.get user {
      field_name = "id"
      field_value = $entry_b.user_id
    } as $user_b
  
    precondition ($user_a != null && $user_b != null) {
      error_type = "notfound"
      error = "Entry owner not found"
    }
  
    // Tournament context: weight classes, wrestlers, matches
    db.query weight_class {
      where = $db.weight_class.tournament_id == $entry_a.tournament_id
      return = {type: "list"}
    } as $weight_classes
  
    db.query wrestler {
      where = $db.wrestler.tournament_id == $entry_a.tournament_id
      return = {type: "list"}
    } as $wrestlers
  
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $entry_a.tournament_id
      return = {type: "list"}
    } as $matches
  
    // All picks for both entries
    db.query user_pick {
      where = $db.user_pick.user_bracket_id == $entry_a.id
      return = {type: "list"}
    } as $picks_a
  
    db.query user_pick {
      where = $db.user_pick.user_bracket_id == $entry_b.id
      return = {type: "list"}
    } as $picks_b
  
    // Lookup maps
    var $wc_map {
      value = {}
    }
  
    foreach ($weight_classes) {
      each as $wc {
        var.update $wc_map {
          value = $wc_map|set:$wc.id:$wc
        }
      }
    }
  
    var $wrestler_map {
      value = {}
    }
  
    foreach ($wrestlers) {
      each as $w {
        var.update $wrestler_map {
          value = $wrestler_map|set:$w.id:$w
        }
      }
    }
  
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
  
    var $pick_map_a {
      value = {}
    }
  
    foreach ($picks_a) {
      each as $p {
        var.update $pick_map_a {
          value = $pick_map_a|set:$p.bracket_match_id:$p
        }
      }
    }
  
    var $pick_map_b {
      value = {}
    }
  
    foreach ($picks_b) {
      each as $p {
        var.update $pick_map_b {
          value = $pick_map_b|set:$p.bracket_match_id:$p
        }
      }
    }
  
    // Walk A's picks and compare against B's pick on the same match
    var $common_picks {
      value = 0
    }
  
    var $differing_picks {
      value = 0
    }
  
    var $a_correct {
      value = 0
    }
  
    var $b_correct {
      value = 0
    }
  
    var $decisive_matches {
      value = []
    }
  
    foreach ($picks_a) {
      each as $pa {
        var $pb {
          value = $pick_map_b[$pa.bracket_match_id]
        }
      
        conditional {
          if ($pb != null) {
            var $a_ok {
              value = $pa.outcome_status == "correct" || $pa.is_correct == true
            }
          
            var $b_ok {
              value = $pb.outcome_status == "correct" || $pb.is_correct == true
            }
          
            conditional {
              if ($a_ok) {
                math.add $a_correct {
                  value = 1
                }
              }
            }
          
            conditional {
              if ($b_ok) {
                math.add $b_correct {
                  value = 1
                }
              }
            }
          
            conditional {
              if ($pa.picked_wrestler_id == $pb.picked_wrestler_id) {
                math.add $common_picks {
                  value = 1
                }
              }
            
              else {
                math.add $differing_picks {
                  value = 1
                }
              
                // Decisive: match still open AND at least one picked wrestler
                // is still a participant in the match
                var $m {
                  value = $match_map[$pa.bracket_match_id]
                }
              
                conditional {
                  if ($m != null && ($m.match_status == "pending" || $m.match_status == "in_progress")) {
                    var $a_alive {
                      value = $m.actual_top_wrestler_id == $pa.picked_wrestler_id || $m.actual_bottom_wrestler_id == $pa.picked_wrestler_id
                    }
                  
                    var $b_alive {
                      value = $m.actual_top_wrestler_id == $pb.picked_wrestler_id || $m.actual_bottom_wrestler_id == $pb.picked_wrestler_id
                    }
                  
                    conditional {
                      if ($a_alive || $b_alive) {
                        var $wc {
                          value = $wc_map[$m.weight_class_id]
                        }
                      
                        var $weight_value {
                          value = null
                        }
                      
                        conditional {
                          if ($wc != null) {
                            var.update $weight_value {
                              value = $wc.weight
                            }
                          }
                        }
                      
                        var $wa {
                          value = $wrestler_map[$pa.picked_wrestler_id]
                        }
                      
                        var $a_pick_summary {
                          value = null
                        }
                      
                        conditional {
                          if ($wa != null) {
                            var.update $a_pick_summary {
                              value = {
                                id    : $wa.id
                                name  : $wa.name
                                seed  : $wa.seed
                                school: $wa.school
                              }
                            }
                          }
                        }
                      
                        var $wb {
                          value = $wrestler_map[$pb.picked_wrestler_id]
                        }
                      
                        var $b_pick_summary {
                          value = null
                        }
                      
                        conditional {
                          if ($wb != null) {
                            var.update $b_pick_summary {
                              value = {
                                id    : $wb.id
                                name  : $wb.name
                                seed  : $wb.seed
                                school: $wb.school
                              }
                            }
                          }
                        }
                      
                        array.push $decisive_matches {
                          value = {
                            id          : $m.id
                            round_label : $m.round_label
                            weight      : $weight_value
                            match_number: $m.match_number
                            a_pick      : $a_pick_summary
                            b_pick      : $b_pick_summary
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
  
    // Champions per side: weight value -> picked wrestler name (champ_finals picks)
    var $champions_a {
      value = {}
    }
  
    var $champions_b {
      value = {}
    }
  
    foreach ($matches) {
      each as $m {
        conditional {
          if ($m.round_code == "champ_finals") {
            var $wc {
              value = $wc_map[$m.weight_class_id]
            }
          
            conditional {
              if ($wc != null) {
                var $pa {
                  value = $pick_map_a[$m.id]
                }
              
                conditional {
                  if ($pa != null) {
                    var $wa {
                      value = $wrestler_map[$pa.picked_wrestler_id]
                    }
                  
                    conditional {
                      if ($wa != null) {
                        var.update $champions_a {
                          value = $champions_a|set:$wc.weight:$wa.name
                        }
                      }
                    }
                  }
                }
              
                var $pb {
                  value = $pick_map_b[$m.id]
                }
              
                conditional {
                  if ($pb != null) {
                    var $wb {
                      value = $wrestler_map[$pb.picked_wrestler_id]
                    }
                  
                    conditional {
                      if ($wb != null) {
                        var.update $champions_b {
                          value = $champions_b|set:$wc.weight:$wb.name
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
  
    // Entry summaries
    var $summary_a {
      value = {
        id                : $entry_a.id
        status            : $entry_a.status
        total_points      : $entry_a.total_points
        possible_points   : $entry_a.possible_points
        rank              : $entry_a.rank
        correct_pick_count: $entry_a.correct_pick_count
        scored_pick_count : $entry_a.scored_pick_count
        champions_correct : $entry_a.champions_correct
        submitted_at      : $entry_a.submitted_at
        user              : {
          id          : $user_a.id
          username    : $user_a.username
          display_name: $user_a.display_name
          avatar_url  : $user_a.avatar_url
        }
      }
    }
  
    var $summary_b {
      value = {
        id                : $entry_b.id
        status            : $entry_b.status
        total_points      : $entry_b.total_points
        possible_points   : $entry_b.possible_points
        rank              : $entry_b.rank
        correct_pick_count: $entry_b.correct_pick_count
        scored_pick_count : $entry_b.scored_pick_count
        champions_correct : $entry_b.champions_correct
        submitted_at      : $entry_b.submitted_at
        user              : {
          id          : $user_b.id
          username    : $user_b.username
          display_name: $user_b.display_name
          avatar_url  : $user_b.avatar_url
        }
      }
    }
  }

  response = {
    a               : $summary_a
    b               : $summary_b
    common_picks    : $common_picks
    differing_picks : $differing_picks
    a_correct       : $a_correct
    b_correct       : $b_correct
    decisive_matches: $decisive_matches
    champions       : ```
      {
        a: $champions_a
        b: $champions_b
      }
      ```
  }
}
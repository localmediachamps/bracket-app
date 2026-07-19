// Scores a single pick'em (salary-cap) entry against current results (ARCHITECTURE.md section 7).
// Each picked wrestler earns: placement points (final bracket placement 1st-8th,
// derived from the completed champ_finals / place_3 / place_5 / place_7 matches on
// the pick's weight class), win points per completed win by section, and bonus
// points by victory_type. Stores a {placement, wins, bonus} breakdown on each
// pickem_pick and the summed total on the entry. Idempotent and deterministic.
// Score one pick'em entry: per-pick placement/win/bonus points plus entry total
function score_pickem_entry {
  input {
    // The pickem_entry to score
    int pickem_entry_id
  }

  stack {
    db.get pickem_entry {
      field_name = "id"
      field_value = $input.pickem_entry_id
    } as $entry
  
    precondition ($entry != null) {
      error_type = "notfound"
      error = "Pick'em entry not found."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $entry.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    // Resolve pick'em config, falling back to defaults
    var $pickem_config {
      value = $tournament.pickem_config
    }
  
    conditional {
      if ($pickem_config == null) {
        function.run get_default_pickem_config as $default_pickem_config
        var.update $pickem_config {
          value = $default_pickem_config
        }
      }
    }
  
    var $scoring_cfg {
      value = $pickem_config|get:"scoring":{}
    }
  
    var $placement_points {
      value = $scoring_cfg|get:"placement_points":{}
    }
  
    var $win_points {
      value = $scoring_cfg|get:"win_points":{}
    }
  
    var $bonus_points {
      value = $scoring_cfg|get:"bonus_points":{}
    }
  
    db.query pickem_pick {
      where = $db.pickem_pick.pickem_entry_id == $input.pickem_entry_id
      return = {type: "list"}
    } as $picks
  
    // All matches in the tournament; wins are found by winner id,
    // placements by weight class + placement round codes
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $entry.tournament_id
      return = {type: "list"}
    } as $all_matches
  
    var $total_points {
      value = 0
    }
  
    var $picks_scored {
      value = 0
    }
  
    foreach ($picks) {
      each as $pick {
        var $wins_pts {
          value = 0
        }
      
        var $bonus_pts {
          value = 0
        }
      
        var $placement_num {
          value = null
        }
      
        foreach ($all_matches) {
          each as $m {
            conditional {
              if ($m.match_status == "complete" || $m.match_status == "corrected") {
                // win + bonus points (byes are not contested wins)
                conditional {
                  if ($m.is_bye != true && $m.actual_winner_wrestler_id == $pick.wrestler_id) {
                    var $wp {
                      value = $win_points|get:$m.bracket_section:null
                    }
                  
                    conditional {
                      if ($wp != null) {
                        math.add $wins_pts {
                          value = $wp
                        }
                      }
                    }
                  
                    conditional {
                      if ($m.victory_type != null) {
                        var $bp {
                          value = $bonus_points|get:$m.victory_type:null
                        }
                      
                        conditional {
                          if ($bp != null) {
                            math.add $bonus_pts {
                              value = $bp
                            }
                          }
                        }
                      }
                    }
                  }
                }
              
                // placement-deciding matches on this pick's weight class
                conditional {
                  if ($m.weight_class_id == $pick.weight_class_id) {
                    conditional {
                      if ($m.round_code == "champ_finals" || $m.round_code == "place_3" || $m.round_code == "place_5" || $m.round_code == "place_7") {
                        // fall back to deriving the loser from the participant slots
                        var $loser_id {
                          value = $m.actual_loser_wrestler_id
                        }
                      
                        conditional {
                          if ($loser_id == null && $m.actual_winner_wrestler_id != null) {
                            conditional {
                              if ($m.actual_top_wrestler_id == $m.actual_winner_wrestler_id) {
                                var.update $loser_id {
                                  value = $m.actual_bottom_wrestler_id
                                }
                              }
                            
                              else {
                                var.update $loser_id {
                                  value = $m.actual_top_wrestler_id
                                }
                              }
                            }
                          }
                        }
                      
                        conditional {
                          if ($m.round_code == "champ_finals") {
                            conditional {
                              if ($m.actual_winner_wrestler_id == $pick.wrestler_id) {
                                var.update $placement_num {
                                  value = 1
                                }
                              }
                            
                              elseif ($loser_id == $pick.wrestler_id) {
                                var.update $placement_num {
                                  value = 2
                                }
                              }
                            }
                          }
                        
                          elseif ($m.round_code == "place_3") {
                            conditional {
                              if ($m.actual_winner_wrestler_id == $pick.wrestler_id) {
                                var.update $placement_num {
                                  value = 3
                                }
                              }
                            
                              elseif ($loser_id == $pick.wrestler_id) {
                                var.update $placement_num {
                                  value = 4
                                }
                              }
                            }
                          }
                        
                          elseif ($m.round_code == "place_5") {
                            conditional {
                              if ($m.actual_winner_wrestler_id == $pick.wrestler_id) {
                                var.update $placement_num {
                                  value = 5
                                }
                              }
                            
                              elseif ($loser_id == $pick.wrestler_id) {
                                var.update $placement_num {
                                  value = 6
                                }
                              }
                            }
                          }
                        
                          elseif ($m.round_code == "place_7") {
                            conditional {
                              if ($m.actual_winner_wrestler_id == $pick.wrestler_id) {
                                var.update $placement_num {
                                  value = 7
                                }
                              }
                            
                              elseif ($loser_id == $pick.wrestler_id) {
                                var.update $placement_num {
                                  value = 8
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
      
        var $placement_pts {
          value = 0
        }
      
        conditional {
          if ($placement_num != null) {
            var $placement_key {
              value = $placement_num|to_text
            }
          
            var $pp {
              value = $placement_points|get:$placement_key:null
            }
          
            conditional {
              if ($pp != null) {
                var.update $placement_pts {
                  value = $pp
                }
              }
            }
          }
        }
      
        var $pick_total {
          value = 0
        }
      
        math.add $pick_total {
          value = $placement_pts
        }
      
        math.add $pick_total {
          value = $wins_pts
        }
      
        math.add $pick_total {
          value = $bonus_pts
        }
      
        var $breakdown {
          value = {
            placement: $placement_pts
            wins     : $wins_pts
            bonus    : $bonus_pts
          }
        }
      
        db.edit pickem_pick {
          field_name = "id"
          field_value = $pick.id
          data = {points_earned: $pick_total, breakdown: $breakdown}
        } as $updated_pick
      
        math.add $total_points {
          value = $pick_total
        }
      
        math.add $picks_scored {
          value = 1
        }
      }
    }
  
    db.edit pickem_entry {
      field_name = "id"
      field_value = $input.pickem_entry_id
      data = {total_points: $total_points, updated_at: "now"}
    } as $updated_entry
  }

  response = {
    pickem_entry_id: $input.pickem_entry_id
    total_points   : $total_points
    picks_scored   : $picks_scored
  }
}
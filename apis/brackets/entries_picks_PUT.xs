// Bulk upsert picks for an entry. The client sends the FULL pick set; picks on
// matches absent from the payload are deleted (cascade clearing). Each pick is
// validated: match belongs to the entry's tournament, is not a bye and has no
// final result, and the wrestler is a current participant — resolved through
// the pick chain (not just the match's own actual_top/actual_bottom_wrestler_id,
// which stay unset/0 for any match beyond round 1 until a real result is
// recorded) via a bounded fixpoint over each touched weight class's full match
// graph, mirroring the client's resolvePicks. points_available is snapshotted
// from the tournament scoring config (pigtail -> pigtail; placement section ->
// placement[round_code]; else section[round_number] falling back to the
// nearest defined lower round_number, else 1).
query "entries/{id}/picks" verb=PUT {
  api_group = "brackets"
  auth = "user"

  input {
    // Entry id
    int id
  
    // Full pick set: [{bracket_match_id, wrestler_id}]
    json picks
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.get user_bracket {
      field_name = "id"
      field_value = $input.id
    } as $entry
  
    precondition ($entry != null) {
      error_type = "notfound"
      error = "Entry not found."
    }
  
    precondition ($entry.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "You do not own this entry."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $entry.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    // Editable window: entry draft/submitted and tournament open (or late entries)
    precondition (($entry.status == "draft" || $entry.status == "submitted") && ($tournament.status == "open" || ($tournament.allow_late_entries && ($tournament.status == "locked" || $tournament.status == "live")))) {
      error_type = "inputerror"
      error = "Entry is not editable."
    }
  
    // Scoring config with default fallback
    var $config {
      value = $tournament.scoring_config
    }
  
    conditional {
      if ($config == null) {
        function.run get_default_scoring_config as $default_config
        var.update $config {
          value = $default_config
        }
      }
    }
  
    // ------------------------------------------------------------------
    // Pass 1: fetch + basic-validate every match in the payload; collect
    // the picks map (matchId text -> wrestlerId) and the distinct weight
    // classes touched, needed to resolve cascading participants below.
    // ------------------------------------------------------------------
    var $picks_map {
      value = {}
    }
  
    var $weight_class_ids {
      value = []
    }
  
    var $pick_matches {
      value = []
    }
  
    foreach ($input.picks) {
      each as $pick {
        db.get bracket_match {
          field_name = "id"
          field_value = $pick.bracket_match_id
        } as $match
      
        precondition ($match != null && $match.tournament_id == $entry.tournament_id) {
          error_type = "inputerror"
          error = "Invalid match in picks payload."
        }
      
        precondition ($match.is_bye == false && $match.match_status != "complete" && $match.match_status != "corrected" && $match.match_status != "cancelled") {
          error_type = "inputerror"
          error = "Match is not open for picks."
        }
      
        var.update $picks_map {
          value = $picks_map
            |set:($match.id|to_text):$pick.wrestler_id
        }
      
        conditional {
          if (($weight_class_ids|some:$$ == $match.weight_class_id) == false) {
            array.push $weight_class_ids {
              value = $match.weight_class_id
            }
          }
        }
      
        array.push $pick_matches {
          value = {match: $match, wrestler_id: $pick.wrestler_id}
        }
      }
    }
  
    // ------------------------------------------------------------------
    // Pass 2: resolve every match's current top/bottom participant per
    // touched weight class via a bounded fixpoint (picks cascade through
    // match_winner/match_loser sources). Seed-sourced slots resolve from
    // the match's own actual_top/bottom_wrestler_id (0 means unset).
    // ------------------------------------------------------------------
    var $resolved_map {
      value = {}
    }
  
    foreach ($weight_class_ids) {
      each as $wc_id {
        db.query bracket_match {
          where = $db.bracket_match.weight_class_id == $wc_id
          return = {type: "list"}
        } as $wc_matches
      
        var $wc_resolved {
          value = {}
        }
      
        for (6) {
          each as $pass_idx {
            foreach ($wc_matches) {
              each as $m {
                var $mkey {
                  value = $m.id|to_text
                }
              
                var $top_val {
                  value = null
                }
              
                conditional {
                  if ($m.top_source_type == "seed") {
                    conditional {
                      if (($m.actual_top_wrestler_id|first_notnull:0) > 0) {
                        var.update $top_val {
                          value = $m.actual_top_wrestler_id
                        }
                      }
                    }
                  }
                
                  elseif ($m.top_source_type == "match_winner") {
                    conditional {
                      if (($m.top_source_match_id|first_notnull:0) > 0) {
                        var $skey {
                          value = $m.top_source_match_id|to_text
                        }
                      
                        conditional {
                          if ($picks_map|has:$skey) {
                            var.update $top_val {
                              value = $picks_map[$skey]
                            }
                          }
                        }
                      }
                    }
                  }
                
                  elseif ($m.top_source_type == "match_loser") {
                    conditional {
                      if (($m.top_source_match_id|first_notnull:0) > 0) {
                        var $lkey {
                          value = $m.top_source_match_id|to_text
                        }
                      
                        var $lpick {
                          value = null
                        }
                      
                        conditional {
                          if ($picks_map|has:$lkey) {
                            var.update $lpick {
                              value = $picks_map[$lkey]
                            }
                          }
                        }
                      
                        var $lres {
                          value = null
                        }
                      
                        conditional {
                          if ($wc_resolved|has:$lkey) {
                            var.update $lres {
                              value = $wc_resolved[$lkey]
                            }
                          }
                        }
                      
                        conditional {
                          if ($lpick != null && $lres != null) {
                            conditional {
                              if ($lres.top == $lpick) {
                                var.update $top_val {
                                  value = $lres.bottom
                                }
                              }
                            
                              elseif ($lres.bottom == $lpick) {
                                var.update $top_val {
                                  value = $lres.top
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              
                var $bottom_val {
                  value = null
                }
              
                conditional {
                  if ($m.bottom_source_type == "seed") {
                    conditional {
                      if (($m.actual_bottom_wrestler_id|first_notnull:0) > 0) {
                        var.update $bottom_val {
                          value = $m.actual_bottom_wrestler_id
                        }
                      }
                    }
                  }
                
                  elseif ($m.bottom_source_type == "match_winner") {
                    conditional {
                      if (($m.bottom_source_match_id|first_notnull:0) > 0) {
                        var $bskey {
                          value = $m.bottom_source_match_id|to_text
                        }
                      
                        conditional {
                          if ($picks_map|has:$bskey) {
                            var.update $bottom_val {
                              value = $picks_map[$bskey]
                            }
                          }
                        }
                      }
                    }
                  }
                
                  elseif ($m.bottom_source_type == "match_loser") {
                    conditional {
                      if (($m.bottom_source_match_id|first_notnull:0) > 0) {
                        var $blkey {
                          value = $m.bottom_source_match_id|to_text
                        }
                      
                        var $blpick {
                          value = null
                        }
                      
                        conditional {
                          if ($picks_map|has:$blkey) {
                            var.update $blpick {
                              value = $picks_map[$blkey]
                            }
                          }
                        }
                      
                        var $blres {
                          value = null
                        }
                      
                        conditional {
                          if ($wc_resolved|has:$blkey) {
                            var.update $blres {
                              value = $wc_resolved[$blkey]
                            }
                          }
                        }
                      
                        conditional {
                          if ($blpick != null && $blres != null) {
                            conditional {
                              if ($blres.top == $blpick) {
                                var.update $bottom_val {
                                  value = $blres.bottom
                                }
                              }
                            
                              elseif ($blres.bottom == $blpick) {
                                var.update $bottom_val {
                                  value = $blres.top
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              
                var.update $wc_resolved {
                  value = $wc_resolved
                    |set:$mkey:{top: $top_val, bottom: $bottom_val}
                }
              }
            }
          }
        }
      
        foreach ($wc_matches) {
          each as $m2 {
            var $mkey2 {
              value = $m2.id|to_text
            }
          
            var.update $resolved_map {
              value = $resolved_map|set:$mkey2:$wc_resolved[$mkey2]
            }
          }
        }
      }
    }
  
    var $saved {
      value = 0
    }
  
    var $payload_match_ids {
      value = []
    }
  
    foreach ($pick_matches) {
      each as $pm {
        var $match {
          value = $pm.match
        }
      
        var $mvkey {
          value = $match.id|to_text
        }
      
        var $participants {
          value = $resolved_map[$mvkey]
        }
      
        precondition ($participants != null && ($participants.top == $pm.wrestler_id || $participants.bottom == $pm.wrestler_id)) {
          error_type = "inputerror"
          error = "Wrestler is not a current participant of this match."
        }
      
        // Resolve points_available from the scoring config
        var $points_available {
          value = 1
        }
      
        conditional {
          if ($match.round_code == "pigtail") {
            var.update $points_available {
              value = $config.bracket.pigtail
            }
          }
        
          elseif ($match.bracket_section == "placement") {
            var $placement_cfg {
              value = $config.bracket.placement
            }
          
            var $placement_points {
              value = null
            }
          
            conditional {
              if ($placement_cfg|has:$match.round_code) {
                var.update $placement_points {
                  value = $placement_cfg[$match.round_code]
                }
              }
            }
          
            conditional {
              if ($placement_points != null) {
                var.update $points_available {
                  value = $placement_points
                }
              }
            }
          }
        
          else {
            var $bracket_cfg {
              value = $config.bracket
            }
          
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
                // Exact round, else nearest defined lower round_number
                var $rn {
                  value = $match.round_number
                }
              
                var $resolved {
                  value = null
                }
              
                while ($resolved == null && $rn >= 1) {
                  each {
                    var $rn_key {
                      value = $rn|to_text
                    }
                  
                    var $candidate {
                      value = null
                    }
                  
                    conditional {
                      if ($section_map|has:$rn_key) {
                        var.update $candidate {
                          value = $section_map[$rn_key]
                        }
                      }
                    }
                  
                    conditional {
                      if ($candidate != null) {
                        var.update $resolved {
                          value = $candidate
                        }
                      }
                    }
                  
                    math.sub $rn {
                      value = 1
                    }
                  }
                }
              
                conditional {
                  if ($resolved != null) {
                    var.update $points_available {
                      value = $resolved
                    }
                  }
                }
              }
            }
          }
        }
      
        // Upsert by unique (user_bracket_id, bracket_match_id)
        db.query user_pick {
          where = $db.user_pick.user_bracket_id == $entry.id && $db.user_pick.bracket_match_id == $match.id
          return = {type: "single"}
        } as $existing_pick
      
        conditional {
          if ($existing_pick != null) {
            db.edit user_pick {
              field_name = "id"
              field_value = $existing_pick.id
              data = {
                picked_wrestler_id: $pm.wrestler_id
                points_available  : $points_available
                outcome_status    : "pending"
                is_correct        : null
                points_earned     : null
                updated_at        : now
              }
            } as $updated_pick
          }
        
          else {
            db.add user_pick {
              data = {
                created_at        : now
                updated_at        : now
                user_bracket_id   : $entry.id
                user_id           : $auth.id
                tournament_id     : $entry.tournament_id
                bracket_match_id  : $match.id
                picked_wrestler_id: $pm.wrestler_id
                points_available  : $points_available
                outcome_status    : "pending"
              }
            } as $new_pick
          }
        }
      
        math.add $saved {
          value = 1
        }
      
        array.push $payload_match_ids {
          value = $match.id
        }
      }
    }
  
    // Cascade clear: delete this entry's picks on matches absent from the payload
    db.query user_pick {
      where = $db.user_pick.user_bracket_id == $entry.id
      return = {type: "list"}
    } as $current_picks
  
    var $cleared {
      value = []
    }
  
    foreach ($current_picks) {
      each as $cp {
        conditional {
          if (($payload_match_ids|some:$$ == $cp.bracket_match_id) == false) {
            db.del user_pick {
              field_name = "id"
              field_value = $cp.id
            }
          
            array.push $cleared {
              value = $cp.bracket_match_id
            }
          }
        }
      }
    }
  
    function.run tournament_progress {
      input = {
        tournament_id  : $entry.tournament_id
        user_bracket_id: $entry.id
      }
    } as $progress
  }

  response = {
    saved   : $saved
    cleared : $cleared
    progress: {picked: $progress.picked, total: $progress.total_matches}
  }

  guid = "XfuilEUmzBEgxJu167ndMhCOWIE"
}
// Bulk upsert picks for an entry. The client sends the FULL pick set; picks on
// matches absent from the payload are deleted (cascade clearing). Each pick is
// validated: match belongs to the entry's tournament, is not a bye and has no
// final result, and the wrestler is a current participant. points_available is
// snapshotted from the tournament scoring config (pigtail -> pigtail; placement
// section -> placement[round_code]; else section[round_number] falling back to
// the nearest defined lower round_number, else 1).
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
  
    var $saved {
      value = 0
    }
  
    var $payload_match_ids {
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
      
        precondition ($match.actual_top_wrestler_id == $pick.wrestler_id || $match.actual_bottom_wrestler_id == $pick.wrestler_id) {
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
            var $placement_points {
              value = $config.bracket.placement|get:$match.round_code
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
            var $section_map {
              value = $config.bracket|get:$match.bracket_section
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
                    var $candidate {
                      value = $section_map|get:($rn|to_text)
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
                picked_wrestler_id: $pick.wrestler_id
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
                picked_wrestler_id: $pick.wrestler_id
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
}
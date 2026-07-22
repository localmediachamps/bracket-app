// Entry review: champion pick per weight class, correct/scored pick counts
// and points earned per weight class, totals, and the count of non-bye
// matches still missing a pick. Viewable by the owner, any other logged-in
// user when the entry has opted into is_public, or a site admin. Requires
// login even for the is_public case (not truly anonymous) - Xano only
// populates $auth.id when auth="user" is declared, and declaring it means
// login is required platform-side before the stack ever runs; there's no
// documented "populate if present, don't require" mode. Confirmed
// empirically 2026-07-22: a real owner's valid Bearer token was still
// ignored (is_owner always false) when this endpoint had no auth clause.
query "entries/{id}/review" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    // Entry id
    int id
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

    var $is_owner {
      value = $entry.user_id == $auth.id
    }

    var $can_view {
      value = $is_owner || $entry.is_public
    }

    conditional {
      if ($can_view == false) {
        db.get user {
          field_name = "id"
          field_value = $auth.id
          output = ["id", "is_admin"]
        } as $requester

        conditional {
          if ($requester != null && $requester.is_admin) {
            var.update $can_view {
              value = true
            }
          }
        }
      }
    }

    precondition ($can_view) {
      error_type = "accessdenied"
      error = "This entry is private."
    }

    db.get user {
      field_name = "id"
      field_value = $entry.user_id
      output = ["id", "username", "display_name", "avatar_url"]
    } as $entry_user

    db.query weight_class {
      where = $db.weight_class.tournament_id == $entry.tournament_id
      sort = {weight_class.display_order: "asc"}
      return = {type: "list"}
    } as $classes
  
    db.query user_pick {
      where = $db.user_pick.user_bracket_id == $entry.id
      return = {type: "list"}
    } as $picks
  
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $entry.tournament_id
      return = {type: "list"}
    } as $matches
  
    // Match lookup by id
    var $match_map {
      value = {}
    }
  
    foreach ($matches) {
      each as $mm {
        var.update $match_map {
          value = $match_map|set:$mm.id:$mm
        }
      }
    }
  
    var $wc_rows {
      value = []
    }
  
    var $total_correct {
      value = 0
    }
  
    var $total_scored {
      value = 0
    }
  
    var $total_points {
      value = 0
    }
  
    foreach ($classes) {
      each as $wc {
        // Find this weight class's championship finals match
        var $champ_match_id {
          value = null
        }
      
        foreach ($matches) {
          each as $m {
            conditional {
              if ($m.weight_class_id == $wc.id && $m.round_code == "champ_finals") {
                var.update $champ_match_id {
                  value = $m.id
                }
              }
            }
          }
        }
      
        // Champion pick = this entry's pick on the finals match
        var $champion {
          value = null
        }

        var $champion_correct {
          value = null
        }

        conditional {
          if ($champ_match_id != null) {
            foreach ($picks) {
              each as $p {
                conditional {
                  if ($p.bracket_match_id == $champ_match_id) {
                    db.get wrestler {
                      field_name = "id"
                      field_value = $p.picked_wrestler_id
                      output = ["id", "name", "school", "seed"]
                    } as $champ_wrestler

                    var.update $champion {
                      value = $champ_wrestler
                    }

                    conditional {
                      if ($p.outcome_status == "correct") {
                        var.update $champion_correct {
                          value = true
                        }
                      }
                      elseif ($p.outcome_status == "incorrect" || $p.outcome_status == "eliminated") {
                        var.update $champion_correct {
                          value = false
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      
        // Per-weight pick stats
        var $wc_correct {
          value = 0
        }
      
        var $wc_scored {
          value = 0
        }
      
        var $wc_points {
          value = 0
        }
      
        foreach ($picks) {
          each as $wp {
            var $pick_match {
              value = null
            }
          
            conditional {
              if ($match_map|has:$wp.bracket_match_id) {
                var.update $pick_match {
                  value = $match_map[$wp.bracket_match_id]
                }
              }
            }
          
            conditional {
              if ($pick_match != null && $pick_match.weight_class_id == $wc.id) {
                conditional {
                  if ($wp.outcome_status == "correct") {
                    math.add $wc_correct {
                      value = 1
                    }
                  
                    math.add $wc_scored {
                      value = 1
                    }
                  
                    math.add $wc_points {
                      value = $wp.points_earned|first_notnull:0
                    }
                  }
                
                  elseif ($wp.outcome_status == "incorrect" || $wp.outcome_status == "eliminated") {
                    math.add $wc_scored {
                      value = 1
                    }
                  }
                }
              }
            }
          }
        }
      
        array.push $wc_rows {
          value = {
            weight_class_id : $wc.id
            weight          : $wc.weight
            name            : $wc.name
            champion        : $champion
            champion_correct: $champion_correct
            correct         : $wc_correct
            scored          : $wc_scored
            points_earned   : $wc_points
          }
        }
      
        math.add $total_correct {
          value = $wc_correct
        }
      
        math.add $total_scored {
          value = $wc_scored
        }
      
        math.add $total_points {
          value = $wc_points
        }
      }
    }
  
    // Missing = non-bye matches without a pick for this entry
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $entry.tournament_id && $db.bracket_match.is_bye == false
      return = {type: "count"}
    } as $total_matches
  
    var $picked_count {
      value = $picks|count
    }
  
    var $missing_count {
      value = $total_matches - $picked_count
    }
  
    conditional {
      if ($missing_count < 0) {
        var.update $missing_count {
          value = 0
        }
      }
    }
  }

  response = {
    entry         : $entry
    user          : $entry_user
    is_owner      : $is_owner
    weight_classes: $wc_rows
    totals        : {correct: $total_correct, scored: $total_scored, points_earned: $total_points}
    missing       : $missing_count
  }
  guid = "BRgtR6n2M7CYYl9jNtDrouJgoDc"
}
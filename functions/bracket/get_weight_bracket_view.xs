// Bracket view for one weight class (ARCHITECTURE.md section 6 response shape).
// All queries are filtered by weight_class_id / tournament_id / user_bracket_id.
// user_pick data is merged when entry_id is provided (caller verifies ownership).
// pick_percentage is included only when pick_percentages=true (caller gates).
// Full bracket view: weight class, rounds, competitors, enriched matches, optional entry
function get_weight_bracket_view {
  input {
    // Weight class to render
    int weight_class_id
  
    // Tournament the weight class belongs to
    int tournament_id
  
    // Optional user_bracket entry whose picks are merged into matches
    int? entry_id?
  
    // Include per-match pick percentages (caller gates visibility)
    bool? pick_percentages?
  }

  stack {
    db.get weight_class {
      field_name = "id"
      field_value = $input.weight_class_id
    } as $wc
  
    precondition ($wc != null && $wc.tournament_id == $input.tournament_id) {
      error_type = "notfound"
      error = "Weight class not found for this tournament."
    }
  
    db.query bracket_match {
      where = ($db.bracket_match.weight_class_id == $input.weight_class_id) && ($db.bracket_match.tournament_id == $input.tournament_id)
      sort = {display_order: "asc"}
      return = {type: "list"}
    } as $matches
  
    db.query wrestler {
      where = $db.wrestler.weight_class_id == $input.weight_class_id
      sort = {seed: "asc"}
      return = {type: "list"}
      output = ["id", "seed", "name", "school", "record", "withdrawn"]
    } as $wrestlers
  
    // Competitor lookup by id (text key) with the match-slot shape
    var $wrestler_map {
      value = {}
    }
  
    var $competitors {
      value = []
    }
  
    foreach ($wrestlers) {
      each as $w {
        array.push $competitors {
          value = {
            id       : $w.id
            seed     : $w.seed
            name     : $w.name
            school   : $w.school
            record   : $w.record
            withdrawn: $w.withdrawn
          }
        }
      
        var $w_comp {
          value = {
            id    : $w.id
            seed  : $w.seed
            name  : $w.name
            school: $w.school
            record: $w.record
          }
        }
      
        var.update $wrestler_map {
          value = $wrestler_map|set:$w.id:$w_comp
        }
      }
    }
  
    // Match lookup by id (for routing references inside this weight class)
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
  
    // User picks for the requested entry
    var $pick_map {
      value = {}
    }
  
    conditional {
      if ($input.entry_id != null) {
        db.query user_pick {
          where = ($db.user_pick.user_bracket_id == $input.entry_id) && ($db.user_pick.tournament_id == $input.tournament_id)
          return = {type: "list"}
          output = [
            "id"
            "bracket_match_id"
            "picked_wrestler_id"
            "outcome_status"
            "points_available"
            "points_earned"
          ]
        } as $picks
      
        foreach ($picks) {
          each as $p {
            var.update $pick_map {
              value = $pick_map|set:$p.bracket_match_id:$p
            }
          }
        }
      }
    }
  
    // Pick percentages across all entries in the tournament (this class only)
    var $pct_map {
      value = {}
    }
  
    conditional {
      if ($input.pick_percentages) {
        db.query user_pick {
          where = $db.user_pick.tournament_id == $input.tournament_id
          return = {type: "list"}
          output = ["bracket_match_id", "picked_wrestler_id"]
        } as $all_picks
      
        foreach ($all_picks) {
          each as $ap {
            var $ap_match {
              value = $match_map[$ap.bracket_match_id]
            }
          
            conditional {
              if ($ap_match != null) {
                var $ap_counts {
                  value = {top: 0, bottom: 0}
                }
              
                conditional {
                  if ($pct_map|has:$ap.bracket_match_id) {
                    var.update $ap_counts {
                      value = $pct_map[$ap.bracket_match_id]
                    }
                  }
                }
              
                conditional {
                  if ($ap.picked_wrestler_id == $ap_match.actual_top_wrestler_id) {
                    var.update $ap_counts {
                      value = $ap_counts|set:"top":$ap_counts.top + 1
                    }
                  }
                
                  elseif ($ap.picked_wrestler_id == $ap_match.actual_bottom_wrestler_id) {
                    var.update $ap_counts {
                      value = $ap_counts
                        |set:"bottom":$ap_counts.bottom + 1
                    }
                  }
                }
              
                var.update $pct_map {
                  value = $pct_map
                    |set:$ap.bracket_match_id:$ap_counts
                }
              }
            }
          }
        }
      }
    }
  
    // Distinct rounds in display order: championship, placement, consolation
    var $rounds {
      value = []
    }
  
    var $round_index {
      value = {}
    }
  
    var $round_counts {
      value = {}
    }
  
    foreach ($matches) {
      each as $m {
        conditional {
          if (($round_index|has:$m.round_code) == false) {
            var.update $round_index {
              value = $round_index|set:$m.round_code:true
            }
          
            array.push $rounds {
              value = {
                code       : $m.round_code
                number     : $m.round_number
                label      : $m.round_label
                section    : $m.bracket_section
                match_count: 0
              }
            }
          }
        }
      
        var $rc_count {
          value = 0
        }
      
        conditional {
          if ($round_counts|has:$m.round_code) {
            var.update $rc_count {
              value = $round_counts[$m.round_code]
            }
          }
        }
      
        math.add $rc_count {
          value = 1
        }
      
        var.update $round_counts {
          value = $round_counts|set:$m.round_code:$rc_count
        }
      }
    }
  
    // Attach per-round match counts
    var $rounds_final {
      value = []
    }
  
    foreach ($rounds) {
      each as $r {
        var $rc_match_count {
          value = 0
        }
      
        conditional {
          if ($round_counts|has:$r.code) {
            var.update $rc_match_count {
              value = $round_counts[$r.code]
            }
          }
        }
      
        array.push $rounds_final {
          value = $r
            |set:"match_count":$rc_match_count
        }
      }
    }
  
    // Enriched matches
    var $view_matches {
      value = []
    }
  
    foreach ($matches) {
      each as $m {
        // --- top slot ---
        var $top_source {
          value = null
        }
      
        conditional {
          if ($m.top_source_type != null) {
            var.update $top_source {
              value = {}
                |set:"type":$m.top_source_type
                |set_ifnotnull:"seed":$m.top_source_seed
                |set_ifnotnull:"match_id":$m.top_source_match_id
            }
          }
        }
      
        var $top_competitor {
          value = null
        }
      
        conditional {
          if ($m.actual_top_wrestler_id != null) {
            var.update $top_competitor {
              value = $wrestler_map[$m.actual_top_wrestler_id]
            }
          }
        }
      
        // --- bottom slot ---
        var $bottom_source {
          value = null
        }
      
        conditional {
          if ($m.bottom_source_type != null) {
            var.update $bottom_source {
              value = {}
                |set:"type":$m.bottom_source_type
                |set_ifnotnull:"seed":$m.bottom_source_seed
                |set_ifnotnull:"match_id":$m.bottom_source_match_id
            }
          }
        }
      
        var $bottom_competitor {
          value = null
        }
      
        conditional {
          if ($m.actual_bottom_wrestler_id != null) {
            var.update $bottom_competitor {
              value = $wrestler_map[$m.actual_bottom_wrestler_id]
            }
          }
        }
      
        // --- destinations ---
        var $winner_dest {
          value = null
        }
      
        conditional {
          if ($m.winner_advances_to_match_id != null) {
            var.update $winner_dest {
              value = {
                match_id: $m.winner_advances_to_match_id
                slot    : $m.winner_slot_in_next
              }
            }
          }
        }
      
        var $loser_dest {
          value = null
        }
      
        conditional {
          if ($m.loser_drops_to_match_id != null) {
            var.update $loser_dest {
              value = {
                match_id: $m.loser_drops_to_match_id
                slot    : $m.loser_slot_in_next
              }
            }
          }
        }
      
        var $match_obj {
          value = {
            id                  : $m.id
            section             : $m.bracket_section
            round_code          : $m.round_code
            round_number        : $m.round_number
            round_label         : $m.round_label
            match_number        : $m.match_number
            is_bye              : $m.is_bye
            status              : $m.match_status
            score               : $m.actual_score
            victory_type        : $m.victory_type
            version             : $m.version
            top                 : {source: $top_source, competitor: $top_competitor}
            bottom              : {source: $bottom_source, competitor: $bottom_competitor}
            winner_competitor_id: $m.actual_winner_wrestler_id
            loser_competitor_id : $m.actual_loser_wrestler_id
            winner_dest         : $winner_dest
            loser_dest          : $loser_dest
          }
        }
      
        // --- user pick for the requested entry ---
        conditional {
          if ($input.entry_id != null) {
            var $up {
              value = $pick_map[$m.id]
            }
          
            conditional {
              if ($up != null) {
                var $up_obj {
                  value = {
                    wrestler_id     : $up.picked_wrestler_id
                    outcome         : $up.outcome_status
                    points_available: $up.points_available
                    points_earned   : $up.points_earned
                  }
                }
              
                var.update $match_obj {
                  value = $match_obj|set:"user_pick":$up_obj
                }
              }
            }
          }
        }
      
        // --- pick percentages ---
        conditional {
          if ($input.pick_percentages) {
            var $pp_counts {
              value = {top: 0, bottom: 0}
            }
          
            conditional {
              if ($pct_map|has:$m.id) {
                var.update $pp_counts {
                  value = $pct_map[$m.id]
                }
              }
            }
          
            var $pp_total {
              value = $pp_counts.top + $pp_counts.bottom
            }
          
            var $pp_top {
              value = 0
            }
          
            var $pp_bottom {
              value = 0
            }
          
            conditional {
              if ($pp_total > 0) {
                var.update $pp_top {
                  value = ((100 * $pp_counts.top) / $pp_total)|round
                }
              
                var.update $pp_bottom {
                  value = 100 - $pp_top
                }
              }
            }
          
            var.update $match_obj {
              value = $match_obj
                |set:"pick_percentage":{top: $pp_top, bottom: $pp_bottom}
            }
          }
        }
      
        array.push $view_matches {
          value = $match_obj
        }
      }
    }
  
    // Entry summary (same regardless of weight class)
    var $entry_obj {
      value = null
    }
  
    conditional {
      if ($input.entry_id != null) {
        db.get user_bracket {
          field_name = "id"
          field_value = $input.entry_id
        } as $entry
      
        conditional {
          if ($entry != null) {
            db.query bracket_match {
              where = ($db.bracket_match.tournament_id == $input.tournament_id) && ($db.bracket_match.is_bye == false)
              return = {type: "count"}
            } as $total_matches
          
            db.query user_pick {
              where = $db.user_pick.user_bracket_id == $input.entry_id
              return = {type: "count"}
            } as $picked_matches
          
            var.update $entry_obj {
              value = {
                id             : $entry.id
                status         : $entry.status
                total_points   : $entry.total_points
                possible_points: $entry.possible_points
                progress       : {picked: $picked_matches, total: $total_matches}
                complete       : $picked_matches >= $total_matches
              }
            }
          }
        }
      }
    }
  
    var $result {
      value = {
        weight_class: {
          id              : $wc.id
          name            : $wc.name
          weight          : $wc.weight
          display_order   : $wc.display_order
          status          : $wc.status
          bracket_size    : $wc.bracket_size
          competitor_count: $wc.competitor_count
          template        : $wc.bracket_template
        }
        rounds      : $rounds_final
        competitors : $competitors
        matches     : $view_matches
        entry       : $entry_obj
      }
    }
  }

  response = $result
}
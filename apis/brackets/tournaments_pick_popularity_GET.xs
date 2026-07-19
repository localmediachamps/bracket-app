// Pick popularity for a tournament: per-match pick percentages per wrestler plus
// champion pick percentages per weight class. Restricted until the tournament is
// locked/live/completed or show_pick_percentages is enabled. Based on submitted
// entries only.
query "tournaments/{id}/pick-popularity" verb=GET {
  api_group = "brackets"

  input {
    // Tournament id
    int id
  }

  stack {
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    precondition ($tournament.status == "locked" || $tournament.status == "live" || $tournament.status == "completed" || $tournament.show_pick_percentages) {
      error_type = "accessdenied"
      error = "Pick popularity is hidden until the tournament locks."
    }
  
    // Submitted entries are the population for percentages
    db.query user_bracket {
      where = $db.user_bracket.tournament_id == $input.id && ($db.user_bracket.status == "submitted" || $db.user_bracket.status == "locked" || $db.user_bracket.is_submitted)
      return = {type: "list"}
    } as $submitted_entries
  
    var $submitted_count {
      value = $submitted_entries|count
    }
  
    // Picks belonging to submitted entries (join filters on the entry status)
    db.query user_pick {
      join = {
        user_bracket: {
          table: "user_bracket"
          where: $db.user_pick.user_bracket_id == $db.user_bracket.id
        }
      }
    
      where = $db.user_pick.tournament_id == $input.id && ($db.user_bracket.status == "submitted" || $db.user_bracket.status == "locked" || $db.user_bracket.is_submitted)
      return = {type: "list"}
    } as $picks
  
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $input.id && $db.bracket_match.is_bye == false
      return = {type: "list"}
    } as $matches
  
    db.query wrestler {
      where = $db.wrestler.tournament_id == $input.id
      return = {type: "list"}
    } as $wrestlers
  
    // Wrestler summaries keyed by id
    var $wrestler_map {
      value = {}
    }
  
    foreach ($wrestlers) {
      each as $w {
        var.update $wrestler_map {
          value = $wrestler_map
            |set:$w.id:{id: $w.id, name: $w.name, school: $w.school, seed: $w.seed}
        }
      }
    }
  
    // Weight class lookup (id -> weight) for champion rows
    db.query weight_class {
      where = $db.weight_class.tournament_id == $input.id
      return = {type: "list"}
    } as $classes
  
    var $wc_map {
      value = {}
    }
  
    foreach ($classes) {
      each as $cls {
        var.update $wc_map {
          value = $wc_map|set:$cls.id:$cls.weight
        }
      }
    }
  
    // Group picks: match id -> (wrestler id -> count)
    var $pick_counts {
      value = {}
    }
  
    foreach ($picks) {
      each as $p {
        var $match_counts {
          value = $pick_counts|get:$p.bracket_match_id
        }
      
        conditional {
          if ($match_counts == null) {
            var.update $match_counts {
              value = {}
            }
          }
        }
      
        var $current {
          value = $match_counts|get:$p.picked_wrestler_id
        }
      
        conditional {
          if ($current == null) {
            var.update $current {
              value = 0
            }
          }
        }
      
        var.update $match_counts {
          value = $match_counts
            |set:$p.picked_wrestler_id:$current + 1
        }
      
        var.update $pick_counts {
          value = $pick_counts
            |set:$p.bracket_match_id:$match_counts
        }
      }
    }
  
    // Build per-match percentage rows and champion rows per weight class
    var $match_rows {
      value = []
    }
  
    var $champion_rows {
      value = []
    }
  
    foreach ($matches) {
      each as $m {
        var $m_counts {
          value = $pick_counts|get:$m.id
        }
      
        var $pick_rows {
          value = []
        }
      
        conditional {
          if ($m_counts != null) {
            object.entries {
              value = $m_counts
            } as $count_pairs
          
            foreach ($count_pairs) {
              each as $pair {
                var $pct {
                  value = 0
                }
              
                conditional {
                  if ($submitted_count > 0) {
                    var.update $pct {
                      value = ((($pair.value * 100) / $submitted_count)|round:1)
                    }
                  }
                }
              
                array.push $pick_rows {
                  value = {
                    wrestler_id: $pair.key|to_int
                    wrestler   : $wrestler_map|get:$pair.key
                    count      : $pair.value
                    pct        : $pct
                  }
                }
              }
            }
          
            // Rows are returned unsorted; clients sort by pct descending
            // (server-side |sort with typed args is unreliable here).
          }
        }
      
        array.push $match_rows {
          value = {
            match_id       : $m.id
            weight_class_id: $m.weight_class_id
            round_code     : $m.round_code
            match_number   : $m.match_number
            picks          : $pick_rows
          }
        }
      
        conditional {
          if ($m.round_code == "champ_finals") {
            array.push $champion_rows {
              value = {
                weight_class_id: $m.weight_class_id
                weight         : $wc_map|get:$m.weight_class_id
                picks          : $pick_rows
              }
            }
          }
        }
      }
    }
  }

  response = {
    submitted_entries: $submitted_count
    champions        : $champion_rows
    matches          : $match_rows
  }
}
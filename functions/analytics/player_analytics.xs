// Player analytics across all of a user's bracket entries (ARCHITECTURE.md section 9:
// GET /me/analytics).
// Accuracy = correct / scored, where scored = picks on matches with a final result
// (match_status complete or corrected). All ratios are 0-1 rounded to 3 decimals.
// Streaks are computed over scored picks ordered by match completed_at.
// Aggregate a user's pick performance across all tournaments
function player_analytics {
  input {
    // User to analyze
    int user_id
  }

  stack {
    // All bracket entries for this user
    db.query user_bracket {
      where = $db.user_bracket.user_id == $input.user_id
      return = {type: "list"}
    } as $entries
  
    // All picks ever made by this user
    db.query user_pick {
      where = $db.user_pick.user_id == $input.user_id
      return = {type: "list"}
    } as $picks
  
    // Load tournament, match, and weight class context per entered tournament
    var $tournament_map {
      value = {}
    }
  
    var $match_map {
      value = {}
    }
  
    var $wc_map {
      value = {}
    }
  
    foreach ($entries) {
      each as $entry {
        db.get tournament {
          field_name = "id"
          field_value = $entry.tournament_id
        } as $tournament_row
      
        conditional {
          if ($tournament_row != null) {
            var.update $tournament_map {
              value = $tournament_map
                |set:$tournament_row.id:$tournament_row
            }
          }
        }
      
        db.query bracket_match {
          where = $db.bracket_match.tournament_id == $entry.tournament_id
          return = {type: "list"}
        } as $tournament_matches
      
        foreach ($tournament_matches) {
          each as $m {
            var.update $match_map {
              value = $match_map|set:$m.id:$m
            }
          }
        }
      
        db.query weight_class {
          where = $db.weight_class.tournament_id == $entry.tournament_id
          return = {type: "list"}
        } as $tournament_weights
      
        foreach ($tournament_weights) {
          each as $wc {
            var.update $wc_map {
              value = $wc_map|set:$wc.id:$wc
            }
          }
        }
      }
    }
  
    // Aggregation buckets
    var $overall_correct {
      value = 0
    }
  
    var $overall_scored {
      value = 0
    }
  
    var $champ_correct {
      value = 0
    }
  
    var $champ_scored {
      value = 0
    }
  
    var $by_tournament {
      value = {}
    }
  
    var $by_weight {
      value = {}
    }
  
    var $by_round {
      value = {}
    }
  
    var $scored_events {
      value = []
    }
  
    foreach ($picks) {
      each as $p {
        var $m {
          value = $match_map[$p.bracket_match_id]
        }
      
        conditional {
          if ($m != null) {
            var $is_scored {
              value = $m.match_status == "complete" || $m.match_status == "corrected"
            }
          
            conditional {
              if ($is_scored) {
                var $is_correct {
                  value = $p.outcome_status == "correct" || $p.is_correct == true
                }
              
                math.add $overall_scored {
                  value = 1
                }
              
                conditional {
                  if ($is_correct) {
                    math.add $overall_correct {
                      value = 1
                    }
                  }
                }
              
                var $pts {
                  value = 0
                }
              
                conditional {
                  if ($p.points_earned != null) {
                    var.update $pts {
                      value = $p.points_earned
                    }
                  }
                }
              
                // Streak event (needs a completion timestamp to be orderable)
                conditional {
                  if ($m.completed_at != null) {
                    array.push $scored_events {
                      value = {mid: $m.id, ts: $m.completed_at, ok: $is_correct}
                    }
                  }
                }
              
                // Tournament bucket
                var $tb {
                  value = $by_tournament[$p.tournament_id]
                }
              
                conditional {
                  if ($tb == null) {
                    var.update $tb {
                      value = {correct: 0, scored: 0, points: 0}
                    }
                  }
                }
              
                var $tb_correct {
                  value = $tb.correct
                }
              
                conditional {
                  if ($is_correct) {
                    math.add $tb_correct {
                      value = 1
                    }
                  }
                }
              
                var $tb_scored {
                  value = $tb.scored + 1
                }
              
                var $tb_points {
                  value = $tb.points + $pts
                }
              
                var.update $by_tournament {
                  value = $by_tournament
                    |set:$p.tournament_id:{correct: $tb_correct, scored: $tb_scored, points: $tb_points}
                }
              
                // Weight class bucket
                var $wc {
                  value = $wc_map[$m.weight_class_id]
                }
              
                conditional {
                  if ($wc != null) {
                    var $wb {
                      value = $by_weight[$wc.weight]
                    }
                  
                    conditional {
                      if ($wb == null) {
                        var.update $wb {
                          value = {correct: 0, scored: 0, points: 0}
                        }
                      }
                    }
                  
                    var $wb_correct {
                      value = $wb.correct
                    }
                  
                    conditional {
                      if ($is_correct) {
                        math.add $wb_correct {
                          value = 1
                        }
                      }
                    }
                  
                    var $wb_scored {
                      value = $wb.scored + 1
                    }
                  
                    var $wb_points {
                      value = $wb.points + $pts
                    }
                  
                    var.update $by_weight {
                      value = $by_weight
                        |set:$wc.weight:{correct: $wb_correct, scored: $wb_scored, points: $wb_points}
                    }
                  }
                }
              
                // Round bucket
                var $rb {
                  value = $by_round[$m.round_number]
                }
              
                conditional {
                  if ($rb == null) {
                    var.update $rb {
                      value = {correct: 0, scored: 0}
                    }
                  }
                }
              
                var $rb_correct {
                  value = $rb.correct
                }
              
                conditional {
                  if ($is_correct) {
                    math.add $rb_correct {
                      value = 1
                    }
                  }
                }
              
                var $rb_scored {
                  value = $rb.scored + 1
                }
              
                var.update $by_round {
                  value = $by_round
                    |set:$m.round_number:{correct: $rb_correct, scored: $rb_scored}
                }
              
                // Champion accuracy (champ_finals picks only)
                conditional {
                  if ($m.round_code == "champ_finals") {
                    math.add $champ_scored {
                      value = 1
                    }
                  
                    conditional {
                      if ($is_correct) {
                        math.add $champ_correct {
                          value = 1
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
  
    // Order scored events chronologically (min-extraction on completed_at, match id tiebreak)
    var $ordered_events {
      value = []
    }
  
    var $event_pool {
      value = $scored_events
    }
  
    while (($event_pool|count) > 0) {
      each {
        var $min_event {
          value = $event_pool|first
        }
      
        foreach ($event_pool) {
          each as $ev {
            conditional {
              if ($ev.ts < $min_event.ts || ($ev.ts == $min_event.ts && $ev.mid < $min_event.mid)) {
                var.update $min_event {
                  value = $ev
                }
              }
            }
          }
        }
      
        array.push $ordered_events {
          value = $min_event
        }
      
        var.update $event_pool {
          value = $event_pool
            |lambda_filter:"return $this.mid != " ~ $min_event.mid ~ ";"
        }
      }
    }
  
    // Walk chronologically: current streak = trailing run of correct picks
    var $current_streak {
      value = 0
    }
  
    var $best_streak {
      value = 0
    }
  
    foreach ($ordered_events) {
      each as $ev {
        conditional {
          if ($ev.ok) {
            math.add $current_streak {
              value = 1
            }
          
            conditional {
              if ($current_streak > $best_streak) {
                var.update $best_streak {
                  value = $current_streak
                }
              }
            }
          }
        
          else {
            var.update $current_streak {
              value = 0
            }
          }
        }
      }
    }
  
    // Percentile per tournament (rank vs field size) and best finish
    var $percentile_sum {
      value = 0
    }
  
    var $percentile_count {
      value = 0
    }
  
    var $best_rank {
      value = null
    }
  
    var $best_tournament_name {
      value = null
    }
  
    foreach ($entries) {
      each as $entry {
        conditional {
          if ($entry.rank != null) {
            // Field size = non-draft entries in this tournament
            db.query user_bracket {
              where = $db.user_bracket.tournament_id == $entry.tournament_id && $db.user_bracket.status != "draft"
              return = {type: "count"}
            } as $field_size
          
            conditional {
              if ($field_size > 0) {
                var $percentile {
                  value = 1
                }
              
                conditional {
                  if ($field_size > 1) {
                    var.update $percentile {
                      value = 1 - (($entry.rank - 1) / ($field_size - 1))
                    }
                  }
                }
              
                math.add $percentile_sum {
                  value = $percentile
                }
              
                math.add $percentile_count {
                  value = 1
                }
              }
            }
          
            conditional {
              if ($best_rank == null || $entry.rank < $best_rank) {
                var.update $best_rank {
                  value = $entry.rank
                }
              
                var $best_tournament {
                  value = $tournament_map[$entry.tournament_id]
                }
              
                conditional {
                  if ($best_tournament != null) {
                    var.update $best_tournament_name {
                      value = $best_tournament.name
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  
    var $avg_percentile {
      value = 0
    }
  
    conditional {
      if ($percentile_count > 0) {
        var $percentile_raw {
          value = ($percentile_sum * 1000) / $percentile_count
        }
      
        var.update $avg_percentile {
          value = ($percentile_raw|round) / 1000
        }
      }
    }
  
    // By-tournament output rows
    var $by_tournament_out {
      value = []
    }
  
    foreach ($entries) {
      each as $entry {
        var $tb {
          value = $by_tournament[$entry.tournament_id]
        }
      
        conditional {
          if ($tb == null) {
            var.update $tb {
              value = {correct: 0, scored: 0, points: 0}
            }
          }
        }
      
        var $tournament_row {
          value = $tournament_map[$entry.tournament_id]
        }
      
        var $tournament_name {
          value = null
        }
      
        conditional {
          if ($tournament_row != null) {
            var.update $tournament_name {
              value = $tournament_row.name
            }
          }
        }
      
        var $t_accuracy {
          value = 0
        }
      
        conditional {
          if ($tb.scored > 0) {
            var $t_accuracy_raw {
              value = ($tb.correct * 1000) / $tb.scored
            }
          
            var.update $t_accuracy {
              value = ($t_accuracy_raw|round) / 1000
            }
          }
        }
      
        array.push $by_tournament_out {
          value = {
            tournament_id: $entry.tournament_id
            name         : $tournament_name
            accuracy     : $t_accuracy
            points       : $entry.total_points
            rank         : $entry.rank
          }
        }
      }
    }
  
    // By-weight output rows, ordered by weight ascending (min-extraction)
    var $weight_keys {
      value = $by_weight|keys
    }
  
    var $by_weight_out {
      value = []
    }
  
    while (($weight_keys|count) > 0) {
      each {
        var $min_wk {
          value = $weight_keys|first
        }
      
        foreach ($weight_keys) {
          each as $wk {
            conditional {
              if (($wk|to_int) < ($min_wk|to_int)) {
                var.update $min_wk {
                  value = $wk
                }
              }
            }
          }
        }
      
        var $wb {
          value = $by_weight[$min_wk]
        }
      
        var $w_accuracy {
          value = 0
        }
      
        conditional {
          if ($wb.scored > 0) {
            var $w_accuracy_raw {
              value = ($wb.correct * 1000) / $wb.scored
            }
          
            var.update $w_accuracy {
              value = ($w_accuracy_raw|round) / 1000
            }
          }
        }
      
        array.push $by_weight_out {
          value = {
            weight  : $min_wk|to_int
            accuracy: $w_accuracy
            correct : $wb.correct
            scored  : $wb.scored
          }
        }
      
        var.update $weight_keys {
          value = $weight_keys|remove:$min_wk
        }
      }
    }
  
    // By-round output rows, ordered by round_number ascending (min-extraction)
    var $round_keys {
      value = $by_round|keys
    }
  
    var $by_round_out {
      value = []
    }
  
    while (($round_keys|count) > 0) {
      each {
        var $min_rk {
          value = $round_keys|first
        }
      
        foreach ($round_keys) {
          each as $rk {
            conditional {
              if (($rk|to_int) < ($min_rk|to_int)) {
                var.update $min_rk {
                  value = $rk
                }
              }
            }
          }
        }
      
        var $rb {
          value = $by_round[$min_rk]
        }
      
        var $r_accuracy {
          value = 0
        }
      
        conditional {
          if ($rb.scored > 0) {
            var $r_accuracy_raw {
              value = ($rb.correct * 1000) / $rb.scored
            }
          
            var.update $r_accuracy {
              value = ($r_accuracy_raw|round) / 1000
            }
          }
        }
      
        array.push $by_round_out {
          value = {round_number: $min_rk|to_int, accuracy: $r_accuracy}
        }
      
        var.update $round_keys {
          value = $round_keys|remove:$min_rk
        }
      }
    }
  
    // Most successful weights: top 3 by points earned (max-extraction)
    var $weight_points_pool {
      value = []
    }
  
    foreach ($by_weight|keys) {
      each as $wk {
        var $wb {
          value = $by_weight[$wk]
        }
      
        array.push $weight_points_pool {
          value = {weight: $wk|to_int, points: $wb.points}
        }
      }
    }
  
    var $top_weights {
      value = []
    }
  
    for (3) {
      each as $i {
        conditional {
          if (($weight_points_pool|count) > 0) {
            var $best_weight {
              value = $weight_points_pool|first
            }
          
            foreach ($weight_points_pool) {
              each as $cand {
                conditional {
                  if ($cand.points > $best_weight.points || ($cand.points == $best_weight.points && $cand.weight < $best_weight.weight)) {
                    var.update $best_weight {
                      value = $cand
                    }
                  }
                }
              }
            }
          
            array.push $top_weights {
              value = $best_weight
            }
          
            var.update $weight_points_pool {
              value = $weight_points_pool
                |lambda_filter:"return $this.weight != " ~ $best_weight.weight ~ ";"
            }
          }
        }
      }
    }
  
    // Overall + champion accuracy
    var $overall_accuracy {
      value = 0
    }
  
    conditional {
      if ($overall_scored > 0) {
        var $overall_accuracy_raw {
          value = ($overall_correct * 1000) / $overall_scored
        }
      
        var.update $overall_accuracy {
          value = ($overall_accuracy_raw|round) / 1000
        }
      }
    }
  
    var $champ_accuracy {
      value = 0
    }
  
    conditional {
      if ($champ_scored > 0) {
        var $champ_accuracy_raw {
          value = ($champ_correct * 1000) / $champ_scored
        }
      
        var.update $champ_accuracy {
          value = ($champ_accuracy_raw|round) / 1000
        }
      }
    }
  }

  response = {
    user_id                : $input.user_id
    overall_accuracy       : $overall_accuracy
    correct_picks          : $overall_correct
    scored_picks           : $overall_scored
    by_tournament          : $by_tournament_out
    by_weight_class        : $by_weight_out
    by_round               : $by_round_out
    champion_accuracy      : $champ_accuracy
    current_streak         : $current_streak
    best_streak            : $best_streak
    avg_percentile         : $avg_percentile
    best_finish            : ```
      {
        rank           : $best_rank
        tournament_name: $best_tournament_name
      }
      ```
    most_successful_weights: $top_weights
  }
}
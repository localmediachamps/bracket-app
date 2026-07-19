// Tournament analytics for the admin dashboard (ARCHITECTURE.md section 9:
// GET /admin/tournaments/{id}/analytics).
// Averages are rounded to 2 decimals, ratios (pct) to 3 decimals (0-1).
// "Scored" matches are those with match_status complete or corrected.
// Aggregate entry, pick, and match stats for one tournament
function tournament_analytics {
  input {
    // Tournament to analyze
    int tournament_id
  }

  stack {
    db.get tournament {
      field_name = "id"
      field_value = $input.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found"
    }
  
    // All entries (any status)
    db.query user_bracket {
      where = $db.user_bracket.tournament_id == $input.tournament_id
      return = {type: "list"}
    } as $entries
  
    db.query fantasy_group {
      where = $db.fantasy_group.tournament_id == $input.tournament_id
      return = {type: "count"}
    } as $group_count
  
    // Non-bye matches (byes are excluded from picks and scoring)
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $input.tournament_id && $db.bracket_match.is_bye == false
      return = {type: "list"}
    } as $matches
  
    db.query weight_class {
      where = $db.weight_class.tournament_id == $input.tournament_id
      return = {type: "list"}
    } as $weight_classes
  
    // All picks in this tournament (one filtered scan, aggregated in memory)
    db.query user_pick {
      where = $db.user_pick.tournament_id == $input.tournament_id
      return = {type: "list"}
      output = [
        "id"
        "user_bracket_id"
        "bracket_match_id"
        "picked_wrestler_id"
        "outcome_status"
        "is_correct"
      ]
    } as $picks
  
    // Entry counts, score accumulation, per-day entry counts
    var $total_entries {
      value = $entries|count
    }
  
    var $draft_count {
      value = 0
    }
  
    var $submitted_count {
      value = 0
    }
  
    var $locked_count {
      value = 0
    }
  
    var $score_sum {
      value = 0
    }
  
    var $score_count {
      value = 0
    }
  
    var $scores {
      value = []
    }
  
    var $submitted_flag_count {
      value = 0
    }
  
    var $day_counts {
      value = {}
    }
  
    foreach ($entries) {
      each as $e {
        conditional {
          if ($e.status == "draft") {
            math.add $draft_count {
              value = 1
            }
          }
        
          elseif ($e.status == "submitted") {
            math.add $submitted_count {
              value = 1
            }
          }
        
          elseif ($e.status == "locked") {
            math.add $locked_count {
              value = 1
            }
          }
        }
      
        conditional {
          if ($e.status != "draft") {
            var $tp {
              value = 0
            }
          
            conditional {
              if ($e.total_points != null) {
                var.update $tp {
                  value = $e.total_points
                }
              }
            }
          
            math.add $score_sum {
              value = $tp
            }
          
            math.add $score_count {
              value = 1
            }
          
            array.push $scores {
              value = $tp
            }
          }
        }
      
        conditional {
          if ($e.submitted_at != null) {
            math.add $submitted_flag_count {
              value = 1
            }
          }
        }
      
        var $entry_day {
          value = $e.created_at|format_timestamp:"Y-m-d":"UTC"
        }
      
        var $day_cur {
          value = $day_counts[$entry_day]
        }
      
        conditional {
          if ($day_cur == null) {
            var.update $day_cur {
              value = 0
            }
          }
        }
      
        math.add $day_cur {
          value = 1
        }
      
        var.update $day_counts {
          value = $day_counts|set:$entry_day:$day_cur
        }
      }
    }
  
    // Average score over submitted + locked entries
    var $avg_score {
      value = 0
    }
  
    conditional {
      if ($score_count > 0) {
        var $avg_raw {
          value = ($score_sum * 100) / $score_count
        }
      
        var.update $avg_score {
          value = ($avg_raw|round) / 100
        }
      }
    }
  
    // Score histogram: 10 equal-width buckets over submitted + locked totals
    var $histogram {
      value = []
    }
  
    conditional {
      if (($scores|count) > 0) {
        var $min_score {
          value = $scores|min
        }
      
        var $max_score {
          value = $scores|max
        }
      
        var $bucket_width {
          value = ($max_score - $min_score) / 10
        }
      
        var $buckets {
          value = []
        }
      
        for (10) {
          each as $i {
            array.push $buckets {
              value = 0
            }
          }
        }
      
        foreach ($scores) {
          each as $s {
            var $bucket_idx {
              value = 0
            }
          
            conditional {
              if ($bucket_width > 0) {
                var.update $bucket_idx {
                  value = (($s - $min_score) / $bucket_width)|floor
                }
              }
            }
          
            conditional {
              if ($bucket_idx > 9) {
                var.update $bucket_idx {
                  value = 9
                }
              }
            }
          
            // Increment the bucket at $bucket_idx (arrays are values, rebuild)
            var $new_buckets {
              value = []
            }
          
            for ($buckets|count) {
              each as $j {
                conditional {
                  if ($j == $bucket_idx) {
                    array.push $new_buckets {
                      value = ($buckets[$j]) + 1
                    }
                  }
                
                  else {
                    array.push $new_buckets {
                      value = $buckets[$j]
                    }
                  }
                }
              }
            }
          
            var.update $buckets {
              value = $new_buckets
            }
          }
        }
      
        for (10) {
          each as $i {
            var $bucket_lo_raw {
              value = $min_score + ($i * $bucket_width)
            }
          
            var $bucket_hi_raw {
              value = $min_score + (($i + 1) * $bucket_width)
            }
          
            array.push $histogram {
              value = {
                bucket: $i + 1
                min   : (($bucket_lo_raw * 100)|round) / 100
                max   : (($bucket_hi_raw * 100)|round) / 100
                count : $buckets[$i]
              }
            }
          }
        }
      }
    }
  
    // Weight class lookup
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
  
    // Per-match pick totals: match_id -> {total, correct}
    var $match_stats {
      value = {}
    }
  
    foreach ($picks) {
      each as $p {
        var $stat {
          value = $match_stats[$p.bracket_match_id]
        }
      
        conditional {
          if ($stat == null) {
            var.update $stat {
              value = {total: 0, correct: 0}
            }
          }
        }
      
        var $stat_total {
          value = $stat.total + 1
        }
      
        var $stat_correct {
          value = $stat.correct
        }
      
        conditional {
          if ($p.outcome_status == "correct" || $p.is_correct) {
            math.add $stat_correct {
              value = 1
            }
          }
        }
      
        var.update $match_stats {
          value = $match_stats
            |set:$p.bracket_match_id:{total: $stat_total, correct: $stat_correct}
        }
      }
    }
  
    // Pool of scored matches with at least one pick
    var $match_pool {
      value = []
    }
  
    foreach ($matches) {
      each as $m {
        conditional {
          if ($m.match_status == "complete" || $m.match_status == "corrected") {
            var $stat {
              value = $match_stats[$m.id]
            }
          
            conditional {
              if ($stat != null && $stat.total > 0) {
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
              
                var $pct_raw {
                  value = ($stat.correct * 1000) / $stat.total
                }
              
                array.push $match_pool {
                  value = {
                    match_id     : $m.id
                    round_label  : $m.round_label
                    weight       : $weight_value
                    match_number : $m.match_number
                    total_picks  : $stat.total
                    correct_picks: $stat.correct
                    pct          : ($pct_raw|round) / 1000
                  }
                }
              }
            }
          }
        }
      }
    }
  
    // Top 10 most correctly predicted matches (pct desc, total desc, id asc)
    var $most_correct {
      value = []
    }
  
    var $pool_top {
      value = $match_pool
    }
  
    for (10) {
      each as $i {
        conditional {
          if (($pool_top|count) > 0) {
            var $top_match {
              value = $pool_top|first
            }
          
            foreach ($pool_top) {
              each as $c {
                conditional {
                  if ($c.pct > $top_match.pct || ($c.pct == $top_match.pct && $c.total_picks > $top_match.total_picks) || ($c.pct == $top_match.pct && $c.total_picks == $top_match.total_picks && $c.match_id < $top_match.match_id)) {
                    var.update $top_match {
                      value = $c
                    }
                  }
                }
              }
            }
          
            array.push $most_correct {
              value = $top_match
            }
          
            var.update $pool_top {
              value = $pool_top
                |lambda_filter:"return $this.match_id != " ~ $top_match.match_id ~ ";"
            }
          }
        }
      }
    }
  
    // Top 10 least correctly predicted matches (pct asc, total desc, id asc)
    var $least_correct {
      value = []
    }
  
    var $pool_bottom {
      value = $match_pool
    }
  
    for (10) {
      each as $i {
        conditional {
          if (($pool_bottom|count) > 0) {
            var $bottom_match {
              value = $pool_bottom|first
            }
          
            foreach ($pool_bottom) {
              each as $c {
                conditional {
                  if ($c.pct < $bottom_match.pct || ($c.pct == $bottom_match.pct && $c.total_picks > $bottom_match.total_picks) || ($c.pct == $bottom_match.pct && $c.total_picks == $bottom_match.total_picks && $c.match_id < $bottom_match.match_id)) {
                    var.update $bottom_match {
                      value = $c
                    }
                  }
                }
              }
            }
          
            array.push $least_correct {
              value = $bottom_match
            }
          
            var.update $pool_bottom {
              value = $pool_bottom
                |lambda_filter:"return $this.match_id != " ~ $bottom_match.match_id ~ ";"
            }
          }
        }
      }
    }
  
    // Most-picked champion per weight class.
    // pct denominator = total entries (drafts included, drafts can hold picks).
    var $champion_picks {
      value = []
    }
  
    foreach ($weight_classes) {
      each as $wc {
        db.query bracket_match {
          where = $db.bracket_match.tournament_id == $input.tournament_id && $db.bracket_match.weight_class_id == $wc.id && $db.bracket_match.round_code == "champ_finals"
          return = {type: "single"}
        } as $finals_match
      
        conditional {
          if ($finals_match != null) {
            db.query user_pick {
              where = $db.user_pick.bracket_match_id == $finals_match.id
              return = {type: "list"}
              output = ["id", "picked_wrestler_id"]
            } as $finals_picks
          
            conditional {
              if (($finals_picks|count) > 0) {
                // Count picks per wrestler
                var $wrestler_counts {
                  value = {}
                }
              
                foreach ($finals_picks) {
                  each as $fp {
                    var $fp_cur {
                      value = $wrestler_counts[$fp.picked_wrestler_id]
                    }
                  
                    conditional {
                      if ($fp_cur == null) {
                        var.update $fp_cur {
                          value = 0
                        }
                      }
                    }
                  
                    math.add $fp_cur {
                      value = 1
                    }
                  
                    var.update $wrestler_counts {
                      value = $wrestler_counts
                        |set:$fp.picked_wrestler_id:$fp_cur
                    }
                  }
                }
              
                // Wrestler with the most picks
                var $best_wrestler_key {
                  value = null
                }
              
                var $best_wrestler_count {
                  value = 0
                }
              
                foreach ($wrestler_counts|keys) {
                  each as $wkey {
                    var $wcount {
                      value = $wrestler_counts[$wkey]
                    }
                  
                    conditional {
                      if ($best_wrestler_key == null || $wcount > $best_wrestler_count) {
                        var.update $best_wrestler_key {
                          value = $wkey
                        }
                      
                        var.update $best_wrestler_count {
                          value = $wcount
                        }
                      }
                    }
                  }
                }
              
                var $best_wrestler_id {
                  value = $best_wrestler_key|to_int
                }
              
                db.get wrestler {
                  field_name = "id"
                  field_value = $best_wrestler_id
                } as $champ_wrestler
              
                var $wrestler_summary {
                  value = null
                }
              
                conditional {
                  if ($champ_wrestler != null) {
                    var.update $wrestler_summary {
                      value = {
                        id    : $champ_wrestler.id
                        name  : $champ_wrestler.name
                        school: $champ_wrestler.school
                        seed  : $champ_wrestler.seed
                      }
                    }
                  }
                }
              
                var $champ_pct {
                  value = 0
                }
              
                conditional {
                  if ($total_entries > 0) {
                    var $champ_pct_raw {
                      value = ($best_wrestler_count * 1000) / $total_entries
                    }
                  
                    var.update $champ_pct {
                      value = ($champ_pct_raw|round) / 1000
                    }
                  }
                }
              
                array.push $champion_picks {
                  value = {
                    weight  : $wc.weight
                    wrestler: $wrestler_summary
                    picks   : $best_wrestler_count
                    pct     : $champ_pct
                  }
                }
              }
            }
          }
        }
      }
    }
  
    // Completion funnel: viewed -> created entry -> >=50% picks -> submitted
    var $nonbye_map {
      value = {}
    }
  
    foreach ($matches) {
      each as $m {
        var.update $nonbye_map {
          value = $nonbye_map|set:$m.id:true
        }
      }
    }
  
    var $nonbye_total {
      value = $matches|count
    }
  
    var $half_needed {
      value = $nonbye_total / 2
    }
  
    // Pick counts per entry on non-bye matches only
    var $entry_pick_counts {
      value = {}
    }
  
    foreach ($picks) {
      each as $p {
        conditional {
          if ($nonbye_map[$p.bracket_match_id]) {
            var $ep_cur {
              value = $entry_pick_counts[$p.user_bracket_id]
            }
          
            conditional {
              if ($ep_cur == null) {
                var.update $ep_cur {
                  value = 0
                }
              }
            }
          
            math.add $ep_cur {
              value = 1
            }
          
            var.update $entry_pick_counts {
              value = $entry_pick_counts|set:$p.user_bracket_id:$ep_cur
            }
          }
        }
      }
    }
  
    var $fifty_count {
      value = 0
    }
  
    foreach ($entries) {
      each as $e {
        var $ep_cur {
          value = $entry_pick_counts[$e.id]
        }
      
        conditional {
          if ($ep_cur != null && $ep_cur >= $half_needed) {
            math.add $fifty_count {
              value = 1
            }
          }
        }
      }
    }
  
    // Viewed proxy: denormalized entry_count on the tournament row
    var $viewed_proxy {
      value = $tournament.entry_count
    }
  
    conditional {
      if ($viewed_proxy == null) {
        var.update $viewed_proxy {
          value = $total_entries
        }
      }
    }
  
    // Entries over time: count by day (UTC) for the last 30 days, oldest first
    var $now_ms {
      value = "now"|to_ms
    }
  
    var $entries_over_time {
      value = []
    }
  
    for (30) {
      each as $i {
        var $offset_days {
          value = 29 - $i
        }
      
        var $day_ms {
          value = $now_ms - ($offset_days * 86400000)
        }
      
        var $series_day {
          value = $day_ms|format_timestamp:"Y-m-d":"UTC"
        }
      
        var $series_count {
          value = $day_counts[$series_day]
        }
      
        conditional {
          if ($series_count == null) {
            var.update $series_count {
              value = 0
            }
          }
        }
      
        array.push $entries_over_time {
          value = {date: $series_day, count: $series_count}
        }
      }
    }
  }

  response = {
    tournament_id        : $input.tournament_id
    entries              : ```
      {
        total    : $total_entries
        draft    : $draft_count
        submitted: $submitted_count
        locked   : $locked_count
      }
      ```
    group_count          : $group_count
    avg_score            : $avg_score
    score_histogram      : $histogram
    most_picked_champions: $champion_picks
    most_correct_matches : $most_correct
    least_correct_matches: $least_correct
    completion_funnel    : ```
      {
        viewed       : $viewed_proxy
        created_entry: $total_entries
        fifty_pct    : $fifty_count
        submitted    : $submitted_flag_count
      }
      ```
    entries_over_time    : $entries_over_time
  }
}
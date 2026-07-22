// Re-scores every pick'em entry in a tournament (draft|submitted|locked) and
// recomputes the pick'em leaderboard. Ranking: total_points desc, then earliest
// submitted_at (nulls last), id asc as the final deterministic tiebreak.
// prev_rank snapshots the old rank before rank is written. Idempotent.
// Full idempotent rescore and re-rank of a tournament's pick'em entries
function rescore_pickem {
  input {
    // Tournament whose pick'em entries should be rescored
    int tournament_id
  }

  stack {
    db.get tournament {
      field_name = "id"
      field_value = $input.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    db.query pickem_entry {
      where = $db.pickem_entry.tournament_id == $input.tournament_id
      return = {type: "list"}
    } as $entries
  
    var $scored_count {
      value = 0
    }
  
    foreach ($entries) {
      each as $entry {
        conditional {
          if ($entry.status == "submitted" || $entry.status == "locked" || $entry.status == "draft") {
            function.run score_pickem_entry {
              input = {pickem_entry_id: $entry.id}
            } as $score_result
          
            math.add $scored_count {
              value = 1
            }
          }
        }
      }
    }
  
    // Reload fresh totals for ranking
    db.query pickem_entry {
      where = $db.pickem_entry.tournament_id == $input.tournament_id
      return = {type: "list"}
    } as $fresh_entries
  
    // Order entries by repeatedly taking the best remaining one (deterministic)
    var $pool {
      value = []
    }
  
    foreach ($fresh_entries) {
      each as $fe {
        array.push $pool {
          value = $fe
        }
      }
    }
  
    var $ranked {
      value = []
    }
  
    while (($pool|count) > 0) {
      each {
        var $best {
          value = $pool|first
        }
      
        foreach ($pool) {
          each as $cand {
            var $cand_total {
              value = $cand.total_points|first_notnull:0
            }
          
            var $best_total {
              value = $best.total_points|first_notnull:0
            }
          
            var $cand_better {
              value = false
            }
          
            conditional {
              if ($cand_total > $best_total) {
                var.update $cand_better {
                  value = true
                }
              }
            
              elseif ($cand_total == $best_total) {
                // equal totals: earliest submission wins, nulls last, then id asc
                conditional {
                  if ($cand.submitted_at != null && $best.submitted_at == null) {
                    var.update $cand_better {
                      value = true
                    }
                  }
                
                  elseif ($cand.submitted_at != null && $best.submitted_at != null && $cand.submitted_at < $best.submitted_at) {
                    var.update $cand_better {
                      value = true
                    }
                  }
                
                  elseif ($cand.submitted_at != null && $best.submitted_at != null && $cand.submitted_at == $best.submitted_at && $cand.id < $best.id) {
                    var.update $cand_better {
                      value = true
                    }
                  }
                
                  elseif ($cand.submitted_at == null && $best.submitted_at == null && $cand.id < $best.id) {
                    var.update $cand_better {
                      value = true
                    }
                  }
                }
              }
            }
          
            conditional {
              if ($cand_better) {
                var.update $best {
                  value = $cand
                }
              }
            }
          }
        }
      
        array.push $ranked {
          value = $best
        }
      
        var.update $pool {
          value = $pool|remove:$best
        }
      }
    }
  
    // Write ranks; prev_rank snapshots the old rank
    var $ranked_count {
      value = $ranked|count
    }
  
    for ($ranked_count) {
      each as $ridx {
        var $rentry {
          value = $ranked[$ridx]
        }
      
        var $new_rank {
          value = $ridx + 1
        }
      
        db.edit pickem_entry {
          field_name = "id"
          field_value = $rentry.id
          data = {
            prev_rank : $rentry.rank
            rank      : $new_rank
            updated_at: "now"
          }
        } as $ranked_entry
      }
    }

    // Master leaderboard: percentile-based points for genuinely competitive
    // (submitted|locked) entries only - drafts never earn a row here.
    // $ranked has every status mixed together (unlike rescore_tournament.xs,
    // this function never split them into separate pools), so filter down
    // to just submitted|locked, preserving the existing order, then use
    // position within that filtered list as rank_in_tournament.
    var $competitive_ranked {
      value = $ranked|filter:$$.status == "submitted" || $$.status == "locked"
    }

    var $competitive_count {
      value = $competitive_ranked|count
    }

    function.run get_default_platform_leaderboard_config {
      input = {}
    } as $platform_config

    conditional {
      if ($competitive_count > 0) {
        for ($competitive_count) {
          each as $pidx {
            var $pentry {
              value = $competitive_ranked[$pidx]
            }

            var $prank {
              value = $pidx + 1
            }

            var $ppercentile {
              value = ($competitive_count - $prank + 1) / $competitive_count
            }

            var $ppoints {
              value = ($ppercentile|pow:$platform_config.percentile.curve_exponent) * $platform_config.percentile.scale
            }

            db.query platform_leaderboard_entry {
              where = $db.platform_leaderboard_entry.user_id == $pentry.user_id && $db.platform_leaderboard_entry.tournament_id == $input.tournament_id && $db.platform_leaderboard_entry.source_type == "pickem"
              return = {type: "single"}
            } as $existing_ple

            conditional {
              if ($existing_ple != null) {
                db.edit platform_leaderboard_entry {
                  field_name = "id"
                  field_value = $existing_ple.id
                  data = {
                    rank_in_tournament: $prank
                    entrants          : $competitive_count
                    percentile        : $ppercentile
                    points_awarded    : $ppoints
                    scoring_path      : "percentile"
                    year              : $tournament.year
                  }
                } as $updated_ple
              }
              else {
                db.add platform_leaderboard_entry {
                  data = {
                    created_at        : now
                    user_id           : $pentry.user_id
                    tournament_id     : $input.tournament_id
                    source_type       : "pickem"
                    scoring_path      : "percentile"
                    rank_in_tournament: $prank
                    entrants          : $competitive_count
                    percentile        : $ppercentile
                    points_awarded    : $ppoints
                    year              : $tournament.year
                  }
                } as $new_ple
              }
            }
          }
        }
      }
    }
  }

  response = {
    entries_scored: $scored_count
    entries_ranked: $ranked_count
  }
  guid = "NifMMncQyr_5eSYCVp8HmBHjfZs"
}
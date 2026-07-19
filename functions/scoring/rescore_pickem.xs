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
  }

  response = {
    entries_scored: $scored_count
    entries_ranked: $ranked_count
  }
}
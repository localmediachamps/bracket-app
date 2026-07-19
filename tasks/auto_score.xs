// Rescore tournaments flagged with needs_rescore, then send rank-change
// notifications to entries that climbed the leaderboard (improved by 3+
// spots, or reached #1). Runs every 5 minutes (freq 300s).
// rescore_tournament is idempotent, maintains prev_rank, re-ranks, triggers
// the pick'em rescore, and clears the needs_rescore flag itself.
// Rank-change notifications are capped at 50 per run to avoid storms.
// Rescore tournaments with needs_rescore=true and notify users who climbed the leaderboard
task auto_score {
  stack {
    // Tournaments flagged for rescore
    db.query tournament {
      where = $db.tournament.needs_rescore == true
      return = {type: "list"}
    } as $stale_tournaments
  
    // Rank-change notifications sent this run (cap 50)
    var $notified_count {
      value = 0
    }
  
    foreach ($stale_tournaments) {
      each as $tournament {
        // Rescore one tournament; log and continue on failure
        try_catch {
          try {
            // Full idempotent rescore + re-rank (also clears needs_rescore and rescores pick'em)
            function.run rescore_tournament {
              input = {tournament_id: $tournament.id}
            } as $rescore_result
          
            // All entries for rank-change check (rank/prev_rank null filtering done in memory)
            db.query user_bracket {
              where = $db.user_bracket.tournament_id == $tournament.id
              return = {type: "list"}
            } as $entries
          
            foreach ($entries) {
              each as $entry {
                // Entry moved up and notification cap not reached
                conditional {
                  if ($notified_count < 50 && $entry.rank != null && $entry.prev_rank != null && $entry.rank < $entry.prev_rank) {
                    // Leaderboard spots climbed
                    var $improvement {
                      value = $entry.prev_rank - $entry.rank
                    }
                  
                    // Notify only on a jump of 3+ spots or a new #1
                    conditional {
                      if ($improvement >= 3 || $entry.rank == 1) {
                        // Send rank-change notification
                        try_catch {
                          try {
                            function.run notify {
                              input = {
                                user_id: $entry.user_id
                                type   : "rank_change"
                                title  : "You climbed the leaderboard!"
                                body   : "You're now #" ~ $entry.rank ~ " in " ~ $tournament.name
                                data   : {tournament_id: $tournament.id, entry_id: $entry.id}
                              }
                            } as $rank_notify_created
                          
                            math.add $notified_count {
                              value = 1
                            }
                          }
                        
                          catch {
                            // rank_change notify failed for entry
                            debug.log {
                              value = {entry_id: $entry.id, error: $error.message}
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
        
          catch {
            // Rescore failed for tournament
            debug.log {
              value = {tournament_id: $tournament.id, error: $error.message}
            }
          }
        }
      }
    }
  
    // Run summary
    debug.log {
      value = {
        tournaments_rescored: $stale_tournaments|count
        rank_notifications  : $notified_count
      }
    }
  }

  schedule = [{starts_on: 2026-07-18 00:00:00+0000, freq: 300}]
}
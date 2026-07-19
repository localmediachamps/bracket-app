// Hourly deadline reminders (cron equivalent: 7 * * * * — starts at minute 7,
// freq 3600s). Finds open tournaments locking within the next 24 hours and
// reminds owners of draft (unsubmitted) bracket and pick'em entries.
// Dedup guard: skips a user who already has an unread deadline_soon
// notification for the same tournament. Capped at 100 notifications per run.
// Remind users with draft entries about tournaments locking within 24 hours
task deadline_reminders {
  stack {
    // Current timestamp (epoch ms)
    var $now {
      value = now
    }
  
    // 24 hours from now
    var $locks_cutoff {
      value = now|add_secs_to_timestamp:86400
    }
  
    // Open tournaments locking within the next 24 hours
    db.query tournament {
      where = $db.tournament.status == "open" && $db.tournament.locks_at > $now && $db.tournament.locks_at <= $locks_cutoff
      return = {type: "list"}
    } as $locking_tournaments
  
    // Reminders sent this run (cap 100)
    var $notified_count {
      value = 0
    }
  
    foreach ($locking_tournaments) {
      each as $tournament {
        // Milliseconds until lock (timestamps are epoch ms)
        var $ms_left {
          value = $tournament.locks_at - $now
        }
      
        // Whole hours until lock
        var $hours_left {
          value = ($ms_left / 3600000)|round:0
        }
      
        // Draft (incomplete) bracket entries for this tournament
        db.query user_bracket {
          where = $db.user_bracket.tournament_id == $tournament.id && $db.user_bracket.status == "draft"
          return = {type: "list"}
        } as $draft_entries
      
        foreach ($draft_entries) {
          each as $entry {
            // Skip once the run cap is reached
            conditional {
              if ($notified_count < 100) {
                // Existing deadline_soon notifications for this user (unread + same-tournament check done in memory)
                db.query notification {
                  where = $db.notification.user_id == $entry.user_id && $db.notification.type == "deadline_soon"
                  return = {type: "list"}
                } as $existing_notifications
              
                // Dedup guard: true when an unread deadline_soon exists for this tournament
                var $already_notified {
                  value = false
                }
              
                foreach ($existing_notifications) {
                  each as $existing {
                    conditional {
                      if ($existing.read_at == null && $existing.data.tournament_id == $tournament.id) {
                        var.update $already_notified {
                          value = true
                        }
                      }
                    }
                  }
                }
              
                conditional {
                  if ($already_notified == false) {
                    // Send bracket deadline reminder
                    try_catch {
                      try {
                        function.run notify {
                          input = {
                            user_id: $entry.user_id
                            type   : "deadline_soon"
                            title  : "Deadline in " ~ $hours_left ~ "h: " ~ $tournament.name
                            body   : "Your bracket isn't submitted yet. Finish your picks before the lock!"
                            data   : {tournament_id: $tournament.id, entry_id: $entry.id}
                          }
                        } as $reminder_created
                      
                        math.add $notified_count {
                          value = 1
                        }
                      }
                    
                      catch {
                        // deadline_soon notify failed for bracket entry
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
      
        // Draft (incomplete) pick'em entries for this tournament
        db.query pickem_entry {
          where = $db.pickem_entry.tournament_id == $tournament.id && $db.pickem_entry.status == "draft"
          return = {type: "list"}
        } as $draft_pickems
      
        foreach ($draft_pickems) {
          each as $pickem {
            // Skip once the run cap is reached
            conditional {
              if ($notified_count < 100) {
                // Existing deadline_soon notifications for this user (unread + same-tournament check done in memory)
                db.query notification {
                  where = $db.notification.user_id == $pickem.user_id && $db.notification.type == "deadline_soon"
                  return = {type: "list"}
                } as $existing_pickem_notifications
              
                // Dedup guard: true when an unread deadline_soon exists for this tournament
                var $pickem_already_notified {
                  value = false
                }
              
                foreach ($existing_pickem_notifications) {
                  each as $existing_pe {
                    conditional {
                      if ($existing_pe.read_at == null && $existing_pe.data.tournament_id == $tournament.id) {
                        var.update $pickem_already_notified {
                          value = true
                        }
                      }
                    }
                  }
                }
              
                conditional {
                  if ($pickem_already_notified == false) {
                    // Send pick'em deadline reminder
                    try_catch {
                      try {
                        function.run notify {
                          input = {
                            user_id: $pickem.user_id
                            type   : "deadline_soon"
                            title  : "Deadline in " ~ $hours_left ~ "h: " ~ $tournament.name
                            body   : "Your Pick'em entry isn't submitted yet. Finish your picks before the lock!"
                            data   : {tournament_id: $tournament.id, entry_id: $pickem.id}
                          }
                        } as $pickem_reminder_created
                      
                        math.add $notified_count {
                          value = 1
                        }
                      }
                    
                      catch {
                        // deadline_soon notify failed for pick'em entry
                        debug.log {
                          value = {pickem_entry_id: $pickem.id, error: $error.message}
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
  
    // Run summary
    debug.log {
      value = {
        tournaments_checked: $locking_tournaments|count
        reminders_sent     : $notified_count
      }
    }
  }

  schedule = [{starts_on: 2026-07-18 00:07:00+0000, freq: 3600}]
}
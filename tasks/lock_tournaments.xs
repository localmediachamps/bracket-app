// Auto-lock tournaments whose prediction deadline (locks_at) has passed.
// Runs every 5 minutes (freq 300s). For each expired tournament: transition
// status open -> locked, audit the transition (system actor), lock all
// draft|submitted bracket and pick'em entries, and notify each entry owner.
// Notifications are per-user (not fan-out) because data.entry_id differs
// per recipient.
// Lock open tournaments past their locks_at deadline; lock entries and notify owners
task lock_tournaments {
  stack {
    // Current timestamp (epoch ms) for deadline comparisons
    var $now {
      value = now
    }
  
    // Open tournaments whose prediction deadline has passed. locks_at comes
    // back as 0 (not null) when unset, so exclude 0 explicitly — otherwise
    // any open tournament without a deadline gets locked on the next run.
    db.query tournament {
      where = $db.tournament.status == "open" && $db.tournament.locks_at > 0 && $db.tournament.locks_at <= $now
      return = {type: "list"}
    } as $expired_tournaments
  
    foreach ($expired_tournaments) {
      each as $tournament {
        // Lock one tournament end-to-end; log and continue on failure
        try_catch {
          try {
            // Tournament status open -> locked
            db.edit tournament {
              field_name = "id"
              field_value = $tournament.id
              data = {status: "locked"}
            } as $locked_tournament
          
            // Audit the automatic lock transition (system actor)
            function.run audit {
              input = {
                actor_id      : null
                entity_type   : "tournament"
                entity_id     : $tournament.id
                action        : "tournament_locked"
                previous_value: {status: "open"}
                new_value     : {status: "locked"}
                metadata      : {by: "task"}
              }
            } as $audit_row
          
            // Bracket entries still editable for this tournament
            db.query user_bracket {
              where = $db.user_bracket.tournament_id == $tournament.id && ($db.user_bracket.status == "draft" || $db.user_bracket.status == "submitted")
              return = {type: "list"}
            } as $bracket_entries
          
            foreach ($bracket_entries) {
              each as $entry {
                // Lock bracket entry
                db.edit user_bracket {
                  field_name = "id"
                  field_value = $entry.id
                  data = {
                    status    : "locked"
                    locked_at : "now"
                    updated_at: "now"
                  }
                } as $locked_entry
              
                // Notify bracket entry owner
                try_catch {
                  try {
                    function.run notify {
                      input = {
                        user_id: $entry.user_id
                        type   : "entry_locked"
                        title  : "Picks locked: " ~ $tournament.name
                        body   : "The prediction deadline has passed. Good luck!"
                        data   : {tournament_id: $tournament.id, entry_id: $entry.id}
                      }
                    } as $notify_created
                  }
                
                  catch {
                    // entry_locked notify failed for bracket entry
                    debug.log {
                      value = {entry_id: $entry.id, error: $error.message}
                    }
                  }
                }
              }
            }
          
            // Pick'em entries still editable for this tournament
            db.query pickem_entry {
              where = $db.pickem_entry.tournament_id == $tournament.id && ($db.pickem_entry.status == "draft" || $db.pickem_entry.status == "submitted")
              return = {type: "list"}
            } as $pickem_entries
          
            foreach ($pickem_entries) {
              each as $pickem {
                // Lock pick'em entry
                db.edit pickem_entry {
                  field_name = "id"
                  field_value = $pickem.id
                  data = {
                    status    : "locked"
                    locked_at : "now"
                    updated_at: "now"
                  }
                } as $locked_pickem
              
                // Notify pick'em entry owner
                try_catch {
                  try {
                    function.run notify {
                      input = {
                        user_id: $pickem.user_id
                        type   : "entry_locked"
                        title  : "Picks locked: " ~ $tournament.name
                        body   : "The prediction deadline has passed. Good luck!"
                        data   : {tournament_id: $tournament.id, entry_id: $pickem.id}
                      }
                    } as $pickem_notify_created
                  }
                
                  catch {
                    // entry_locked notify failed for pick'em entry
                    debug.log {
                      value = {pickem_entry_id: $pickem.id, error: $error.message}
                    }
                  }
                }
              }
            }
          }
        
          catch {
            // Failed to lock tournament
            debug.log {
              value = {tournament_id: $tournament.id, error: $error.message}
            }
          }
        }
      }
    }
  
    // Run summary
    debug.log {
      value = {tournaments_locked: $expired_tournaments|count}
    }
  }

  schedule = [{starts_on: 2026-07-18 00:00:00+0000, freq: 300}]
}
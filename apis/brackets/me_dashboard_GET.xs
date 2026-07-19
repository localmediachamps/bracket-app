// Player dashboard: my bracket entries (with tournament card, progress, rank),
// my pick'em entries, my groups, unread notification count, and upcoming lock
// deadlines (open tournaments I have entries in locking within 72h).
query "me/dashboard" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    // 72h deadline horizon
    var $deadline_horizon {
      value = now|add_ms_to_timestamp:259200000
    }
  
    // Bracket entries with tournament card + progress
    db.query user_bracket {
      where = $db.user_bracket.user_id == $auth.id
      sort = {user_bracket.created_at: "desc"}
      return = {type: "list"}
    } as $entries
  
    var $entry_rows {
      value = []
    }
  
    var $deadlines {
      value = []
    }
  
    foreach ($entries) {
      each as $e {
        db.get tournament {
          field_name = "id"
          field_value = $e.tournament_id
        } as $t
      
        conditional {
          if ($t != null) {
            function.run tournament_progress {
              input = {tournament_id: $e.tournament_id, user_bracket_id: $e.id}
            } as $prog
          
            array.push $entry_rows {
              value = {
                entry     : $e
                tournament: {
                  id         : $t.id
                  name       : $t.name
                  slug       : $t.slug
                  year       : $t.year
                  status     : $t.status
                  location   : $t.location
                  start_date : $t.start_date
                  end_date   : $t.end_date
                  locks_at   : $t.locks_at
                  entry_count: $t.entry_count
                  game_modes : $t.game_modes
                }
                progress  : {picked: $prog.picked, total: $prog.total_matches}
                rank      : $e.rank
              }
            }
          
            conditional {
              if ($t.status == "open" && $t.locks_at != null && $t.locks_at > now && $t.locks_at <= $deadline_horizon) {
                array.push $deadlines {
                  value = {
                    tournament_id: $t.id
                    name         : $t.name
                    slug         : $t.slug
                    locks_at     : $t.locks_at
                    entry_id     : $e.id
                  }
                }
              }
            }
          }
        }
      }
    }
  
    // Pick'em entries with tournament card + pick progress
    db.query pickem_entry {
      where = $db.pickem_entry.user_id == $auth.id
      sort = {pickem_entry.created_at: "desc"}
      return = {type: "list"}
    } as $pickem_entries
  
    var $pickem_rows {
      value = []
    }
  
    foreach ($pickem_entries) {
      each as $pe {
        db.get tournament {
          field_name = "id"
          field_value = $pe.tournament_id
        } as $pt
      
        conditional {
          if ($pt != null) {
            db.query pickem_pick {
              where = $db.pickem_pick.pickem_entry_id == $pe.id
              return = {type: "count"}
            } as $pickem_pick_count
          
            db.query weight_class {
              where = $db.weight_class.tournament_id == $pe.tournament_id
              return = {type: "count"}
            } as $pickem_wc_count
          
            array.push $pickem_rows {
              value = {
                entry     : $pe
                tournament: {
                  id         : $pt.id
                  name       : $pt.name
                  slug       : $pt.slug
                  year       : $pt.year
                  status     : $pt.status
                  location   : $pt.location
                  start_date : $pt.start_date
                  end_date   : $pt.end_date
                  locks_at   : $pt.locks_at
                  entry_count: $pt.entry_count
                  game_modes : $pt.game_modes
                }
                progress  : {picked: $pickem_pick_count, total: $pickem_wc_count}
                rank      : $pe.rank
              }
            }
          
            conditional {
              if ($pt.status == "open" && $pt.locks_at != null && $pt.locks_at > now && $pt.locks_at <= $deadline_horizon) {
                array.push $deadlines {
                  value = {
                    tournament_id: $pt.id
                    name         : $pt.name
                    slug         : $pt.slug
                    locks_at     : $pt.locks_at
                    entry_id     : $pe.id
                  }
                }
              }
            }
          }
        }
      }
    }
  
    // Active group memberships with tournament names
    db.query group_membership {
      where = $db.group_membership.user_id == $auth.id && $db.group_membership.status == "active"
      return = {type: "list"}
    } as $memberships
  
    var $group_rows {
      value = []
    }
  
    foreach ($memberships) {
      each as $gm {
        db.get fantasy_group {
          field_name = "id"
          field_value = $gm.group_id
        } as $gm_group
      
        conditional {
          if ($gm_group != null) {
            db.get tournament {
              field_name = "id"
              field_value = $gm_group.tournament_id
              output = ["id", "name"]
            } as $gm_tournament
          
            array.push $group_rows {
              value = {
                group          : $gm_group
                role           : $gm.role
                tournament_name: ($gm_tournament != null) ? $gm_tournament.name : null
              }
            }
          }
        }
      }
    }
  
    db.query notification {
      where = $db.notification.user_id == $auth.id && $db.notification.read_at == null
      return = {type: "count"}
    } as $unread_count
  }

  response = {
    entries           : $entry_rows
    pickem_entries    : $pickem_rows
    groups            : $group_rows
    unread_count      : $unread_count
    upcoming_deadlines: $deadlines
  }
}
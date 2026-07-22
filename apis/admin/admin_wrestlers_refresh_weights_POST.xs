// Recomputes canonical_wrestler.current_weight_class for every wrestler who
// has appeared in wrestler_match_history, from their most recent match's
// weight_class - same "denormalized current value, full history lives
// elsewhere" pattern already used for current_team_id. Scans
// wrestler_match_history newest-first in pages and stops early once every
// known canonical_wrestler has been resolved, since an active wrestler's
// most recent match is recent by definition and resolves within the first
// page or two - only long-inactive/graduated wrestlers push the scan deeper.
query "admin/wrestlers/refresh-weights" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.query canonical_wrestler {
      return = {type: "count"}
    } as $total_wrestlers

    var $current_weights {
      value = {}
    }

    var $page {
      value = 1
    }

    var $per_page {
      value = 2000
    }

    var $keep_going {
      value = true
    }

    while ($keep_going && $page <= 60) {
      each {
        db.query wrestler_match_history {
          sort = {wrestler_match_history.occurred_at: "desc"}
          return = {type: "list", paging: {page: $page, per_page: $per_page}}
        } as $batch

        var $items {
          value = $batch.items
        }

        var $batch_count {
          value = ($items|count)
        }

        foreach ($items) {
          each as $m {
            conditional {
              if ($m.winner_canonical_wrestler_id != null && $m.weight_class != null) {
                var $wkey {
                  value = $m.winner_canonical_wrestler_id|to_text
                }

                conditional {
                  if (($current_weights|has:$wkey) == false) {
                    var.update $current_weights {
                      value = $current_weights|set:$wkey:$m.weight_class
                    }
                  }
                }
              }
            }

            conditional {
              if ($m.loser_canonical_wrestler_id != null && $m.weight_class != null) {
                var $lkey {
                  value = $m.loser_canonical_wrestler_id|to_text
                }

                conditional {
                  if (($current_weights|has:$lkey) == false) {
                    var.update $current_weights {
                      value = $current_weights|set:$lkey:$m.weight_class
                    }
                  }
                }
              }
            }
          }
        }

        conditional {
          if ($batch_count < $per_page) {
            var.update $keep_going {
              value = false
            }
          }
        }

        conditional {
          if (($current_weights|keys|count) >= $total_wrestlers) {
            var.update $keep_going {
              value = false
            }
          }
        }

        math.add $page {
          value = 1
        }
      }
    }

    var $resolved_keys {
      value = ($current_weights|keys)
    }

    var $updated_count {
      value = 0
    }

    foreach ($resolved_keys) {
      each as $key {
        var $wid {
          value = $key|to_int
        }

        var $weight {
          value = $current_weights[$key]
        }

        try_catch {
          try {
            db.edit canonical_wrestler {
              field_name = "id"
              field_value = $wid
              data = {current_weight_class: $weight}
            } as $updated

            math.add $updated_count {
              value = 1
            }
          }

          catch {
          }
        }
      }
    }
  }

  response = {
    total_wrestlers: $total_wrestlers
    resolved       : ($resolved_keys|count)
    updated        : $updated_count
    pages_scanned  : ($page - 1)
  }
  guid = "R7mYt3KsXbLdQnEv9FhWpCzUj5oG"
}

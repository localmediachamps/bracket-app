// Cross-tournament master leaderboard - sums platform_leaderboard_entry.
// points_awarded per user for the given year (defaults to the current
// calendar year), across every source_type (bracket/pickem/dual_meet, the
// last not producible yet). Public, same visibility rule as the existing
// tournaments/{id}/leaderboard (a user can opt out entirely via
// leaderboard_visible, and leaderboard_name_mode controls display name the
// same way).
query "platform/leaderboard" verb=GET {
  api_group = "brackets"

  input {
    int? year?
    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    var $target_year {
      value = $input.year
    }

    conditional {
      if ($target_year == null) {
        var.update $target_year {
          value = (now|format_timestamp:"Y":"UTC")|to_int
        }
      }
    }

    db.query platform_leaderboard_entry {
      where = $db.platform_leaderboard_entry.year == $target_year
      return = {type: "list"}
    } as $entries

    // Sum points per user
    var $totals {
      value = {}
    }

    foreach ($entries) {
      each as $e {
        var $key {
          value = $e.user_id|to_text
        }

        // NOT $totals|get:$key:0 - a real XanoScript engine bug (confirmed
        // 2026-07-22) makes |get:key:default return null instead of the
        // default specifically when that default is 0 and the key is
        // missing (any other default value works fine). Explicit has-check
        // avoids it entirely.
        var $running {
          value = 0
        }

        conditional {
          if ($totals|has:$key) {
            var.update $running {
              value = $totals|get:$key:0
            }
          }
        }

        var.update $totals {
          value = $totals|set:$key:($running + $e.points_awarded)
        }
      }
    }

    var $rows {
      value = []
    }

    var $user_id_keys {
      value = $totals|keys
    }

    foreach ($user_id_keys) {
      each as $uid_key {
        db.get user {
          field_name = "id"
          field_value = ($uid_key|to_int)
          output = ["id", "username", "display_name", "avatar_url", "leaderboard_visible", "leaderboard_name_mode"]
        } as $u

        conditional {
          if ($u != null && $u.leaderboard_visible != false) {
            var $label {
              value = $u.display_name|first_notempty:$u.username
            }

            conditional {
              if ($u.leaderboard_name_mode == "username") {
                var.update $label {
                  value = $u.username|first_notempty:$u.display_name
                }
              }
            }

            array.push $rows {
              value = {
                user        : {id: $u.id, username: $u.username, display_name: $label, avatar_url: $u.avatar_url}
                total_points: $totals|get:$uid_key:0
              }
            }
          }
        }
      }
    }

    var $sorted {
      value = $rows|sort:"total_points":"number"|reverse
    }

    var $ranked {
      value = []
    }

    var $rank_counter {
      value = 0
    }

    foreach ($sorted) {
      each as $r {
        math.add $rank_counter {
          value = 1
        }

        array.push $ranked {
          value = $r|set:"rank":$rank_counter
        }
      }
    }

    var $total {
      value = $ranked|count
    }

    var $offset {
      value = ($input.page - 1) * $input.per
    }

    var $page_items {
      value = $ranked|slice:$offset:$input.per
    }
  }

  response = {
    year : $target_year
    items: $page_items
    total: $total
    page : $input.page
    per  : $input.per
  }
  guid = "Nw6vLsRt3QoZmXpBcYe9DgK2fJh"
}

// Season-long league standings - the unified points ledger that decides the
// eventual champion (fantasy league plan, 2026-07-22 conference/nationals
// redesign - see memory: conference_nationals_scoring_redesign). Every
// season_week_tournament_result row, regardless of week_type (head_to_head's
// win/tie/loss converted to flat points, marquee_tournament's contest
// standings, conference/nationals' roster-ranked placement), feeds this same
// sum - there's no separate win/loss champion, just cumulative points.
// Same access rule as leagues_id_GET.xs: leagues have no public tier, only
// an active/invited member, the owner, or a site admin may view standings.
query "leagues/{id}/standings" verb=GET {
  api_group = "league"
  auth = "user"

  input {
    // League id
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get league {
      field_name = "id"
      field_value = $input.id
    } as $league

    precondition ($league != null) {
      error_type = "notfound"
      error = "League not found."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id
      return = {type: "single"}
    } as $my_membership

    db.get user {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "is_admin"]
    } as $requester

    var $is_site_admin {
      value = ($requester != null && $requester.is_admin == true)
    }

    precondition ($league.owner_id == $auth.id || $my_membership != null || $is_site_admin) {
      error_type = "accessdenied"
      error = "You don't have access to this league."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && ($db.league_membership.status == "active" || $db.league_membership.status == "invited")
      return = {type: "list"}
    } as $members

    db.query season_week_tournament_result {
      where = $db.season_week_tournament_result.league_id == $league.id
      return = {type: "list"}
    } as $ledger_rows

    var $totals {
      value = {}
    }

    foreach ($ledger_rows) {
      each as $row {
        var $key {
          value = $row.membership_id|to_text
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
          value = $totals|set:$key:($running + $row.awarded_points)
        }
      }
    }

    var $rows {
      value = []
    }

    foreach ($members) {
      each as $m {
        db.get user {
          field_name = "id"
          field_value = $m.user_id
          output = ["id", "username", "display_name", "avatar_url"]
        } as $member_user

        var $key {
          value = $m.id|to_text
        }

        // Same has-check fix as above - $totals|get:$key:0 alone would
        // return null (not 0) for a member with no ledger rows yet.
        var $season_points {
          value = 0
        }

        conditional {
          if ($totals|has:$key) {
            var.update $season_points {
              value = $totals|get:$key:0
            }
          }
        }

        array.push $rows {
          value = {
            membership_id: $m.id
            user         : $member_user
            wins         : $m.wins
            losses       : $m.losses
            season_points: $season_points
          }
        }
      }
    }

    var $sorted {
      value = $rows|sort:"season_points":"number"|reverse
    }

    var $ranked {
      value = []
    }

    var $rank_counter {
      value = 0
    }

    foreach ($sorted) {
      each as $r {
        math.add $rank_counter { value = 1 }

        array.push $ranked {
          value = $r|set:"rank":$rank_counter
        }
      }
    }
  }

  response = {league_id: $league.id, standings: $ranked}
  guid = "Dw7xTsNk4PvArZoLcYe8FiM3jHu"
}

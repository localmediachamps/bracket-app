// Generates the head-to-head matchup schedule for a league: pairs active
// members for every head_to_head week in the league's season using the
// standard round-robin "circle method" (fix the first member, rotate the
// rest by one position each week), so it repeats naturally if there are
// more head_to_head weeks than a single round-robin needs. Odd member
// counts get a bye (away_membership_id null, same as the existing bye-week
// handling in score_league_weeks.xs). Owner/commissioner only, and only
// once per league - this was a genuine gap: nothing else in the codebase
// ever created a `matchup` row, so no head_to_head week could ever score a
// real win/loss without this.
//
// CONFIRMED BUG (2026-07-23, isolated by bisection): `(chain)|filter:X == Y`
// - a filter-chain result compared with == WITHOUT wrapping the whole
// chain+filter in its own outer parens - throws a fatal, contentless
// "Fatal Error" here when used inside a `var { value = ... }` assignment,
// even though it validates fine and the identical unwrapped shape works
// INSIDE a `conditional { if (...) }` condition elsewhere in this same
// codebase. Always fully wrap: `((chain)|filter:X) == Y`. See CLAUDE.md.
query "leagues/schedule/generate" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int league_id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get league {
      field_name = "id"
      field_value = $input.league_id
    } as $league

    precondition ($league != null) {
      error_type = "notfound"
      error = "League not found."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id
      return = {type: "single"}
    } as $my_membership

    precondition ($my_membership != null && $my_membership.status == "active" && ($my_membership.role == "owner" || $my_membership.role == "commissioner")) {
      error_type = "accessdenied"
      error = "Only the league owner or a commissioner can generate the schedule."
    }

    db.query matchup {
      where = $db.matchup.league_id == $league.id
      return = {type: "exists"}
    } as $already_scheduled

    precondition ($already_scheduled == false) {
      error_type = "inputerror"
      error = "This league already has a schedule."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.status == "active"
      sort = {league_membership.draft_position: "asc"}
      return = {type: "list"}
    } as $members

    db.query season_week {
      where = $db.season_week.season_id == $league.season_id && $db.season_week.week_type == "head_to_head"
      sort = {season_week.week_number: "asc"}
      return = {type: "list"}
    } as $weeks

    var $order {
      value = []
    }

    foreach ($members) {
      each as $m {
        array.push $order {
          value = $m.id
        }
      }
    }

    var $is_odd {
      value = (($order|count)|modulus:2) == 1
    }

    conditional {
      if ($is_odd) {
        array.push $order {
          value = null
        }
      }
    }

    var $n {
      value = $order|count
    }

    var $half {
      value = ($n / 2)|floor
    }

    var $created {
      value = 0
    }

    foreach ($weeks) {
      each as $week {
        var $i {
          value = 0
        }

        while (`$i < $half`) {
          each {
            var $home_id {
              value = $order|slice:$i:1|first
            }

            var $away_pos {
              value = $n - 1 - $i
            }

            var $away_id {
              value = $order|slice:$away_pos:1|first
            }

            conditional {
              if ($home_id != null && $away_id != null) {
                db.add matchup {
                  data = {
                    created_at        : now
                    league_id         : $league.id
                    season_week_id    : $week.id
                    home_membership_id: $home_id
                    away_membership_id: $away_id
                    result            : "pending"
                    status            : "scheduled"
                  }
                } as $new_matchup

                math.add $created { value = 1 }
              }
              elseif ($home_id != null) {
                db.add matchup {
                  data = {
                    created_at        : now
                    league_id         : $league.id
                    season_week_id    : $week.id
                    home_membership_id: $home_id
                    away_membership_id: null
                    result            : "pending"
                    status            : "scheduled"
                  }
                } as $bye_matchup_a

                math.add $created { value = 1 }
              }
              elseif ($away_id != null) {
                db.add matchup {
                  data = {
                    created_at        : now
                    league_id         : $league.id
                    season_week_id    : $week.id
                    home_membership_id: $away_id
                    away_membership_id: null
                    result            : "pending"
                    status            : "scheduled"
                  }
                } as $bye_matchup_b

                math.add $created { value = 1 }
              }
            }

            math.add $i { value = 1 }
          }
        }

        // Rotate for next week: [order[0], order[n-1], order[1..n-2]] -
        // classic circle-method rotation, position 0 stays fixed.
        var $rot_first {
          value = $order|slice:0:1
        }

        var $rot_last {
          value = $order|slice:($n - 1):1
        }

        var $rot_middle {
          value = $order|slice:1:($n - 2)
        }

        var $new_order {
          value = $rot_first
        }

        array.merge $new_order {
          value = $rot_last
        }

        array.merge $new_order {
          value = $rot_middle
        }

        var.update $order {
          value = $new_order
        }
      }
    }
  }

  response = {
    matchups_created: $created
    weeks           : ($weeks|count)
    members         : ($members|count)
  }
  guid = "UWzeUId642eScRHDwc5KutkghZM"
}

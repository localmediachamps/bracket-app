// Every head-to-head week's full slate of matchups for this league, not
// just the caller's own - a real league scoreboard shows the whole
// league's results each week, the same way standings are league-wide, not
// scoped to "your own record." Grouped by week, most recent first.
query "leagues/matchups/all" verb=GET {
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
      return = {type: "exists"}
    } as $is_member

    precondition ($is_member) {
      error_type = "accessdenied"
      error = "You are not an active member of this league."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id
      return = {type: "list"}
    } as $memberships

    var $member_lookup {
      value = {}
    }

    foreach ($memberships) {
      each as $m {
        db.get user {
          field_name = "id"
          field_value = $m.user_id
          output = ["id", "username", "display_name", "avatar_url"]
        } as $u

        var.update $member_lookup {
          value = $member_lookup|set:($m.id|to_text):$u
        }
      }
    }

    db.query season_week {
      where = $db.season_week.season_id == $league.season_id && $db.season_week.week_type == "head_to_head"
      sort = {season_week.week_number: "desc"}
      return = {type: "list"}
    } as $weeks

    var $weeks_out {
      value = []
    }

    foreach ($weeks) {
      each as $w {
        db.query matchup {
          where = $db.matchup.league_id == $league.id && $db.matchup.season_week_id == $w.id
          return = {type: "list"}
        } as $week_matchups

        var $matchup_rows {
          value = []
        }

        foreach ($week_matchups) {
          each as $mu {
            var $home_key {
              value = ($mu.home_membership_id|to_text)
            }

            var $away_user {
              value = null
            }

            conditional {
              if ($mu.away_membership_id != null) {
                var.update $away_user {
                  value = $member_lookup|get:($mu.away_membership_id|to_text):null
                }
              }
            }

            array.push $matchup_rows {
              value = {
                id            : $mu.id
                home_membership_id: $mu.home_membership_id
                away_membership_id: $mu.away_membership_id
                home_user     : $member_lookup|get:$home_key:null
                away_user     : $away_user
                home_points   : $mu.home_points
                away_points   : $mu.away_points
                result        : $mu.result
                status        : $mu.status
              }
            }
          }
        }

        array.push $weeks_out {
          value = {
            season_week_id: $w.id
            week_number   : $w.week_number
            status        : $w.status
            starts_at     : $w.starts_at
            ends_at       : $w.ends_at
            matchups      : $matchup_rows
          }
        }
      }
    }
  }

  response = {
    weeks: $weeks_out
  }
  guid = "M8sTr3VxNq6ZeYp5KBct9HdOjGl4"
}

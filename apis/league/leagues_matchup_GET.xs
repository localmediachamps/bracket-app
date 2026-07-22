// My head-to-head matchup for a given week - "me" vs "opponent", each side's
// full lineup with per-slot points/record so the client can render a
// side-by-side comparison (fantasy league plan, Phase 9 "Weekly matchup
// screen"). Normalizes home/away into me/opponent so the frontend never has
// to care which side of the underlying `matchup` row it's looking at.
query "leagues/matchup" verb=GET {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int season_week_id
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

    precondition ($my_membership != null && $my_membership.status == "active") {
      error_type = "accessdenied"
      error = "You are not an active member of this league."
    }

    db.get season_week {
      field_name = "id"
      field_value = $input.season_week_id
    } as $season_week

    precondition ($season_week != null && $season_week.week_type == "head_to_head") {
      error_type = "inputerror"
      error = "This isn't a head-to-head week."
    }

    db.query matchup {
      where = $db.matchup.league_id == $league.id && $db.matchup.season_week_id == $season_week.id && (($db.matchup.home_membership_id == $my_membership.id) || ($db.matchup.away_membership_id == $my_membership.id))
      return = {type: "single"}
    } as $matchup

    precondition ($matchup != null) {
      error_type = "notfound"
      error = "You don't have a matchup this week."
    }

    db.get user {
      field_name = "id"
      field_value = $my_membership.user_id
      output = ["id", "username", "display_name", "avatar_url"]
    } as $my_user

    var $i_am_home {
      value = $matchup.home_membership_id == $my_membership.id
    }

    var $opponent_membership_id {
      value = null
    }

    conditional {
      if ($i_am_home) {
        var.update $opponent_membership_id {
          value = $matchup.away_membership_id
        }
      }
      else {
        var.update $opponent_membership_id {
          value = $matchup.home_membership_id
        }
      }
    }

    var $opponent_membership {
      value = null
    }

    var $opponent_user {
      value = null
    }

    conditional {
      if ($opponent_membership_id != null) {
        db.get league_membership {
          field_name = "id"
          field_value = $opponent_membership_id
        } as $opponent_membership

        db.get user {
          field_name = "id"
          field_value = $opponent_membership.user_id
          output = ["id", "username", "display_name", "avatar_url"]
        } as $opponent_user
      }
    }

    // Builds {membership, points, slots:[{wrestler, record, season_weight_class_id,
    // points, match_count, medal_bonus, competed}]} for one membership's
    // lineup this week - shared shape for both me and opponent
    var $my_side {
      value = null
    }

    var $opponent_side {
      value = null
    }

    db.query lineup {
      where = $db.lineup.league_id == $league.id && $db.lineup.membership_id == $my_membership.id && $db.lineup.season_week_id == $season_week.id
      return = {type: "single"}
    } as $my_lineup

    var $my_slots {
      value = []
    }

    conditional {
      if ($my_lineup != null) {
        db.query lineup_slot {
          where = $db.lineup_slot.lineup_id == $my_lineup.id
          return = {type: "list"}
        } as $my_slot_rows

        foreach ($my_slot_rows) {
          each as $s {
            db.get canonical_wrestler {
              field_name = "id"
              field_value = $s.canonical_wrestler_id
              output = ["id", "display_name", "current_team_id"]
            } as $wrestler

            function.run get_wrestler_record_summary {
              input = {canonical_wrestler_id: $s.canonical_wrestler_id}
            } as $record

            array.push $my_slots {
              value = {
                season_weight_class_id: $s.season_weight_class_id
                wrestler              : $wrestler
                record                : $record
                points                : $s.points
                match_count           : $s.match_count
                medal_bonus           : $s.medal_bonus
                competed              : $s.competed
              }
            }
          }
        }
      }
    }

    var $my_points {
      value = 0
    }

    conditional {
      if ($my_lineup != null) {
        var.update $my_points {
          value = $my_lineup.points
        }
      }
    }

    var.update $my_side {
      value = {
        membership_id: $my_membership.id
        user         : $my_user
        points       : $my_points
        slots        : $my_slots
      }
    }

    conditional {
      if ($opponent_membership != null) {
        db.query lineup {
          where = $db.lineup.league_id == $league.id && $db.lineup.membership_id == $opponent_membership.id && $db.lineup.season_week_id == $season_week.id
          return = {type: "single"}
        } as $opp_lineup

        var $opp_slots {
          value = []
        }

        conditional {
          if ($opp_lineup != null) {
            db.query lineup_slot {
              where = $db.lineup_slot.lineup_id == $opp_lineup.id
              return = {type: "list"}
            } as $opp_slot_rows

            foreach ($opp_slot_rows) {
              each as $s {
                db.get canonical_wrestler {
                  field_name = "id"
                  field_value = $s.canonical_wrestler_id
                  output = ["id", "display_name", "current_team_id"]
                } as $opp_wrestler

                function.run get_wrestler_record_summary {
                  input = {canonical_wrestler_id: $s.canonical_wrestler_id}
                } as $opp_record

                array.push $opp_slots {
                  value = {
                    season_weight_class_id: $s.season_weight_class_id
                    wrestler              : $opp_wrestler
                    record                : $opp_record
                    points                : $s.points
                    match_count           : $s.match_count
                    medal_bonus           : $s.medal_bonus
                    competed              : $s.competed
                  }
                }
              }
            }
          }
        }

        var $opp_points {
          value = 0
        }

        conditional {
          if ($opp_lineup != null) {
            var.update $opp_points {
              value = $opp_lineup.points
            }
          }
        }

        var.update $opponent_side {
          value = {
            membership_id: $opponent_membership.id
            user         : $opponent_user
            points       : $opp_points
            slots        : $opp_slots
          }
        }
      }
    }

    var $result {
      value = $matchup.result
    }

    var $my_result {
      value = "pending"
    }

    // Combining (A && B) || (C && D) inline is avoided here - pre-compute
    // each side into its own var first (see CLAUDE.md's XanoScript gotchas
    // re: inline || reliability) rather than trust the compound expression.
    var $won_as_home {
      value = $i_am_home && $result == "home"
    }

    var $won_as_away {
      value = ($i_am_home == false) && $result == "away"
    }

    var $i_won {
      value = $won_as_home || $won_as_away
    }

    conditional {
      if ($result != null && $result != "pending") {
        conditional {
          if ($result == "tie") {
            var.update $my_result {
              value = "tie"
            }
          }
          elseif ($i_won) {
            var.update $my_result {
              value = "win"
            }
          }
          else {
            var.update $my_result {
              value = "loss"
            }
          }
        }
      }
    }
  }

  response = {
    season_week: $season_week
    matchup    : {status: $matchup.status, my_result: $my_result}
    me         : $my_side
    opponent   : $opponent_side
  }
  guid = "Vw6bXqNs4RtMyKpFo9LdGj3uHcT"
}

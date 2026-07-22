// My lineup for a given head-to-head week, plus my full active roster so a
// client can render the "swap in an alternate" picker. Returns lineup=null
// if nothing has been submitted yet.
query "leagues/lineup" verb=GET {
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
      error = "This isn't a head-to-head lineup week."
    }

    db.query lineup {
      where = $db.lineup.league_id == $league.id && $db.lineup.membership_id == $my_membership.id && $db.lineup.season_week_id == $season_week.id
      return = {type: "single"}
    } as $lineup

    var $slot_rows {
      value = []
    }

    conditional {
      if ($lineup != null) {
        db.query lineup_slot {
          where = $db.lineup_slot.lineup_id == $lineup.id
          return = {type: "list"}
        } as $slots

        foreach ($slots) {
          each as $s {
            db.get canonical_wrestler {
              field_name = "id"
              field_value = $s.canonical_wrestler_id
              output = ["id", "display_name", "current_team_id"]
            } as $wrestler

            function.run get_wrestler_record_summary {
              input = {canonical_wrestler_id: $s.canonical_wrestler_id}
            } as $record

            array.push $slot_rows {
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

    db.query roster_slot {
      where = $db.roster_slot.league_id == $league.id && $db.roster_slot.membership_id == $my_membership.id && $db.roster_slot.status == "active"
      return = {type: "list"}
    } as $roster

    var $roster_rows {
      value = []
    }

    foreach ($roster) {
      each as $r {
        db.get canonical_wrestler {
          field_name = "id"
          field_value = $r.canonical_wrestler_id
          output = ["id", "display_name", "current_team_id"]
        } as $roster_wrestler

        db.get season_weight_class {
          field_name = "id"
          field_value = $r.season_weight_class_id
          output = ["id", "weight", "name"]
        } as $roster_weight_class

        function.run get_wrestler_record_summary {
          input = {canonical_wrestler_id: $r.canonical_wrestler_id}
        } as $roster_record

        array.push $roster_rows {
          value = {
            roster_slot_id   : $r.id
            wrestler         : $roster_wrestler
            record           : $roster_record
            drafted_weight_class: $roster_weight_class
            slot_type        : $r.slot_type
            slot_index       : $r.slot_index
          }
        }
      }
    }
  }

  response = {
    season_week: $season_week
    lineup     : $lineup
    slots      : $slot_rows
    roster     : $roster_rows
  }
  guid = "c0jUJlcWRAmhAd8A35t2ISzMeg4"
}

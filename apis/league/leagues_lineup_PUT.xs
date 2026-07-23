// Set (create or replace) my active 10 for a head-to-head week. Every slot
// must name a weight class from this league's season and a wrestler I
// currently own (starter or alternate) - any owned alternate can fill any
// weight's slot this way, which is exactly the bench mechanic from the
// fantasy league plan (point 4: a starter not competing gets benched for an
// alternate). Rejects edits once the week has locked.
query "leagues/lineup" verb=PUT {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int season_week_id

    object[1:20] slots {
      schema {
        int season_weight_class_id
        int canonical_wrestler_id
      }
    }
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

    var $is_lineup_week {
      value = $season_week != null && ($season_week.week_type == "head_to_head" || $season_week.week_type == "conference" || $season_week.week_type == "nationals")
    }

    precondition ($is_lineup_week) {
      error_type = "inputerror"
      error = "This week doesn't take a roster lineup."
    }

    precondition ($season_week.status == "upcoming" || $season_week.status == "open") {
      error_type = "inputerror"
      error = "This week's lineups are locked."
    }

    precondition (($input.slots|count) == $league.roster_starter_slots) {
      error_type = "inputerror"
      error = "You must set exactly " ~ ($league.roster_starter_slots|to_text) ~ " starters."
    }

    // Every named wrestler must be on my active roster in this league, and
    // no wrestler or weight class may repeat across slots
    db.query roster_slot {
      where = $db.roster_slot.league_id == $league.id && $db.roster_slot.membership_id == $my_membership.id && $db.roster_slot.status == "active"
      return = {type: "list"}
    } as $roster

    var $owned_wrestler_ids {
      value = {}
    }

    // Keyed by "wrestlerId:weightClassId" - not just wrestler ownership,
    // since owning a wrestler doesn't mean they can fill ANY weight's lineup
    // slot, only the weight class they're actually rostered at (their
    // starter or alternate slot for that specific weight).
    var $owned_wrestler_weight_pairs {
      value = {}
    }

    foreach ($roster) {
      each as $r {
        var.update $owned_wrestler_ids {
          value = $owned_wrestler_ids|set:($r.canonical_wrestler_id|to_text):true
        }

        var.update $owned_wrestler_weight_pairs {
          value = $owned_wrestler_weight_pairs|set:(($r.canonical_wrestler_id|to_text) ~ ":" ~ ($r.season_weight_class_id|to_text)):true
        }
      }
    }

    var $seen_weight_classes {
      value = {}
    }

    var $seen_wrestlers {
      value = {}
    }

    foreach ($input.slots) {
      each as $slot {
        precondition ($owned_wrestler_ids|has:($slot.canonical_wrestler_id|to_text)) {
          error_type = "inputerror"
          error = "You don't own that wrestler in this league."
        }

        precondition ($owned_wrestler_weight_pairs|has:(($slot.canonical_wrestler_id|to_text) ~ ":" ~ ($slot.season_weight_class_id|to_text))) {
          error_type = "inputerror"
          error = "That wrestler isn't rostered at that weight class."
        }

        precondition (($seen_weight_classes|has:($slot.season_weight_class_id|to_text)) == false) {
          error_type = "inputerror"
          error = "Each weight class can only appear once in your lineup."
        }

        precondition (($seen_wrestlers|has:($slot.canonical_wrestler_id|to_text)) == false) {
          error_type = "inputerror"
          error = "Each wrestler can only appear once in your lineup."
        }

        var.update $seen_weight_classes {
          value = $seen_weight_classes|set:($slot.season_weight_class_id|to_text):true
        }

        var.update $seen_wrestlers {
          value = $seen_wrestlers|set:($slot.canonical_wrestler_id|to_text):true
        }
      }
    }

    db.query lineup {
      where = $db.lineup.league_id == $league.id && $db.lineup.membership_id == $my_membership.id && $db.lineup.season_week_id == $season_week.id
      return = {type: "single"}
    } as $existing_lineup

    var $lineup {
      value = null
    }

    conditional {
      if ($existing_lineup != null) {
        precondition ($existing_lineup.status == "draft" || $existing_lineup.status == "submitted") {
          error_type = "inputerror"
          error = "This lineup is already locked."
        }

        db.query lineup_slot {
          where = $db.lineup_slot.lineup_id == $existing_lineup.id
          return = {type: "list"}
        } as $old_slots

        foreach ($old_slots) {
          each as $old_slot {
            db.del lineup_slot {
              field_name = "id"
              field_value = $old_slot.id
            }
          }
        }

        db.edit lineup {
          field_name = "id"
          field_value = $existing_lineup.id
          data = {status: "submitted"}
        } as $updated_lineup

        var.update $lineup {
          value = $updated_lineup
        }
      }

      else {
        db.add lineup {
          data = {
            created_at    : now
            league_id     : $league.id
            membership_id : $my_membership.id
            season_week_id: $season_week.id
            status        : "submitted"
          }
        } as $new_lineup

        var.update $lineup {
          value = $new_lineup
        }
      }
    }

    foreach ($input.slots) {
      each as $slot {
        db.add lineup_slot {
          data = {
            created_at             : now
            lineup_id              : $lineup.id
            season_weight_class_id : $slot.season_weight_class_id
            canonical_wrestler_id  : $slot.canonical_wrestler_id
          }
        } as $new_slot
      }
    }
  }

  response = $lineup
  guid = "afbnP6Ks8cnZTnEXngMi9Hod4tk"
}

// Make a draft pick. Same endpoint serves both draft contexts:
//   - Preseason draft (season_week_id omitted): rounds 1..roster_starter_slots
//     fill starter weight classes (one wrestler per weight per team, chosen
//     season_weight_class_id required); remaining rounds fill alternates
//     (any weight). Writes a permanent roster_slot.
//   - Tournament mini-draft (season_week_id set): one wrestler per weight,
//     drawn only from that week's linked tournament's actual field, weight
//     class is derived from the wrestler's own tournament entry (no input
//     needed). Writes ONLY draft_pick - never roster_slot - so the
//     season-long roster is untouched and simply continues once the
//     tournament week ends.
query "leagues/draft/pick" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int canonical_wrestler_id
    int? season_week_id?
    int? season_weight_class_id?
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

    db.query draft {
      where = $db.draft.league_id == $league.id && (($input.season_week_id == null && $db.draft.season_week_id == null) || $db.draft.season_week_id == $input.season_week_id)
      return = {type: "single"}
    } as $draft

    precondition ($draft != null && $draft.status == "in_progress") {
      error_type = "inputerror"
      error = "This draft is not in progress."
    }

    var $is_tournament_draft {
      value = ($draft.season_week_id != null)
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id
      return = {type: "single"}
    } as $my_membership

    precondition ($my_membership != null && $my_membership.status == "active") {
      error_type = "accessdenied"
      error = "You are not an active member of this league."
    }

    precondition ($my_membership.id == $draft.current_membership_id) {
      error_type = "inputerror"
      error = "It's not your turn to pick."
    }

    db.get canonical_wrestler {
      field_name = "id"
      field_value = $input.canonical_wrestler_id
    } as $wrestler

    precondition ($wrestler != null) {
      error_type = "notfound"
      error = "Wrestler not found."
    }

    db.query draft_pick {
      where = $db.draft_pick.draft_id == $draft.id && $db.draft_pick.canonical_wrestler_id == $input.canonical_wrestler_id
      return = {type: "exists"}
    } as $wrestler_taken

    precondition ($wrestler_taken == false) {
      error_type = "inputerror"
      error = "This wrestler has already been drafted in this draft."
    }

    var $member_count {
      value = $draft.snake_order|count
    }

    var $round_number {
      value = ((($draft.current_pick_number - 1) / $member_count)|floor) + 1
    }

    var $weight {
      value = null
    }

    var $slot_type {
      value = "alternate"
    }

    var $slot_index {
      value = null
    }

    var $picked_season_weight_class_id {
      value = null
    }

    conditional {
      if ($is_tournament_draft) {
        db.get season_week {
          field_name = "id"
          field_value = $draft.season_week_id
        } as $week

        db.query wrestler {
          where = $db.wrestler.tournament_id == $week.linked_tournament_id && $db.wrestler.canonical_wrestler_id == $input.canonical_wrestler_id
          return = {type: "single"}
        } as $tournament_entry

        precondition ($tournament_entry != null) {
          error_type = "inputerror"
          error = "That wrestler isn't in this tournament's field."
        }

        db.get weight_class {
          field_name = "id"
          field_value = $tournament_entry.weight_class_id
        } as $tourn_weight_class

        var.update $weight {
          value = $tourn_weight_class.weight
        }

        db.query draft_pick {
          where = $db.draft_pick.draft_id == $draft.id && $db.draft_pick.weight == $weight
          return = {type: "exists"}
        } as $weight_taken

        precondition ($weight_taken == false) {
          error_type = "inputerror"
          error = "You already have a pick at that weight in this tournament draft."
        }
      }

      else {
        precondition ($input.season_weight_class_id != null) {
          error_type = "inputerror"
          error = "season_weight_class_id is required for the preseason draft."
        }

        db.get season_weight_class {
          field_name = "id"
          field_value = $input.season_weight_class_id
        } as $weight_class

        precondition ($weight_class != null && $weight_class.season_id == $league.season_id) {
          error_type = "inputerror"
          error = "Invalid weight class for this league's season."
        }

        precondition ($wrestler.current_weight_class == ($weight_class.weight|to_text)) {
          error_type = "inputerror"
          error = "That wrestler competes at " ~ $wrestler.current_weight_class ~ " lbs, not " ~ ($weight_class.weight|to_text) ~ " lbs."
        }

        // Must actually be on that season's real roster - a league scoped to
        // an older season (e.g. a 2025-26 mock league) can only draft
        // wrestlers who competed that year, not next year's signees or
        // wrestlers who'd already graduated by then.
        db.get season {
          field_name = "id"
          field_value = $league.season_id
        } as $draft_season

        function.run season_label_from_year {
          input = {year: $draft_season.year}
        } as $season_label

        db.query canonical_wrestler_team {
          where = $db.canonical_wrestler_team.canonical_wrestler_id == $input.canonical_wrestler_id && $db.canonical_wrestler_team.season_label == $season_label
          return = {type: "exists"}
        } as $on_season_roster

        precondition ($on_season_roster) {
          error_type = "inputerror"
          error = "That wrestler wasn't on an active roster for the " ~ $season_label ~ " season."
        }

        var.update $weight {
          value = $weight_class.weight
        }

        var.update $picked_season_weight_class_id {
          value = $weight_class.id
        }

        conditional {
          if ($round_number <= $league.roster_starter_slots) {
            var.update $slot_type {
              value = "starter"
            }
          }
        }

        conditional {
          if ($slot_type == "starter") {
            db.query roster_slot {
              where = $db.roster_slot.league_id == $league.id && $db.roster_slot.membership_id == $my_membership.id && $db.roster_slot.season_weight_class_id == $input.season_weight_class_id && $db.roster_slot.slot_type == "starter" && $db.roster_slot.status == "active"
              return = {type: "exists"}
            } as $starter_taken

            precondition ($starter_taken == false) {
              error_type = "inputerror"
              error = "You already have a starter at this weight class."
            }
          }

          else {
            // roster_alternate_slots is PER weight class - an alternate at
            // 125 doesn't compete with an alternate at 133 for the cap, the
            // same way starters don't.
            db.query roster_slot {
              where = $db.roster_slot.league_id == $league.id && $db.roster_slot.membership_id == $my_membership.id && $db.roster_slot.season_weight_class_id == $input.season_weight_class_id && $db.roster_slot.slot_type == "alternate" && $db.roster_slot.status == "active"
              return = {type: "list"}
            } as $existing_alternates

            var $alternate_count {
              value = $existing_alternates|count
            }

            precondition ($alternate_count < $league.roster_alternate_slots) {
              error_type = "inputerror"
              error = "You already have the max alternates at this weight class."
            }

            var.update $slot_index {
              value = $alternate_count + 1
            }
          }
        }
      }
    }

    db.add draft_pick {
      data = {
        created_at            : now
        draft_id              : $draft.id
        league_id             : $league.id
        membership_id         : $my_membership.id
        canonical_wrestler_id : $input.canonical_wrestler_id
        overall_pick_number   : $draft.current_pick_number
        round_number          : $round_number
        season_weight_class_id: $picked_season_weight_class_id
        weight                : $weight
        pick_type             : "manual"
        picked_at             : now
      }
    } as $pick

    var $roster_slot {
      value = null
    }

    conditional {
      if ($is_tournament_draft == false) {
        db.add roster_slot {
          data = {
            created_at             : now
            league_id              : $league.id
            membership_id          : $my_membership.id
            canonical_wrestler_id  : $input.canonical_wrestler_id
            season_weight_class_id : $picked_season_weight_class_id
            slot_type              : $slot_type
            slot_index             : $slot_index
            status                 : "active"
            acquired_at            : now
            acquired_via           : "draft"
          }
        } as $new_roster_slot

        var.update $roster_slot {
          value = $new_roster_slot
        }
      }
    }

    function.run advance_draft_turn {
      input = {draft_id: $draft.id}
    } as $draft_updated
  }

  response = {pick: $pick, roster_slot: $roster_slot, draft: $draft_updated}
  guid = "wYG0tVcrPmk293Kt7WQiouU4gF0"
}

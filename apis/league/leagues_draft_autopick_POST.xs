// Autopick for whoever is currently on the clock. Callable by that member
// themselves (they don't want to browse) or by the league owner/commissioner
// (the member is unresponsive) - no enforced pick timer, so this is
// manual-trigger only for now (see the fantasy league plan's open question #2).
//
// Heuristic (placeholder, not final): lowest-id available wrestler. Preseason:
// picker's first still-open starter weight (or the season's first weight for
// an alternate round). Tournament mini-draft: picker's first still-open
// weight from the tournament's own field, lowest-id undrafted wrestler at
// that weight who has a canonical_wrestler link (entries without one can't
// be scored yet - see dependency B - and are skipped).
query "leagues/draft/autopick" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int? season_week_id?
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

    db.get league_membership {
      field_name = "id"
      field_value = $draft.current_membership_id
    } as $on_clock_membership

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id
      return = {type: "single"}
    } as $my_membership

    precondition ($my_membership != null && $my_membership.status == "active") {
      error_type = "accessdenied"
      error = "You are not an active member of this league."
    }

    var $is_league_admin {
      value = ($my_membership.role == "owner" || $my_membership.role == "commissioner")
    }

    precondition ($my_membership.id == $on_clock_membership.id || $is_league_admin) {
      error_type = "accessdenied"
      error = "You can only autopick for yourself, unless you're the league owner or a commissioner."
    }

    var $member_count {
      value = $draft.snake_order|count
    }

    var $round_number {
      value = ((($draft.current_pick_number - 1) / $member_count)|floor) + 1
    }

    db.query draft_pick {
      where = $db.draft_pick.draft_id == $draft.id
      return = {type: "list"}
    } as $existing_picks

    var $drafted_wrestler_map {
      value = {}
    }

    foreach ($existing_picks) {
      each as $p {
        var.update $drafted_wrestler_map {
          value = $drafted_wrestler_map|set:($p.canonical_wrestler_id|to_text):true
        }
      }
    }

    var $chosen_weight {
      value = null
    }

    var $chosen_season_weight_class_id {
      value = null
    }

    var $chosen_wrestler_id {
      value = null
    }

    var $slot_type {
      value = "alternate"
    }

    var $slot_index {
      value = null
    }

    conditional {
      if ($is_tournament_draft) {
        db.get season_week {
          field_name = "id"
          field_value = $draft.season_week_id
        } as $week

        db.query weight_class {
          where = $db.weight_class.tournament_id == $week.linked_tournament_id
          sort = {weight_class.weight: "asc"}
          return = {type: "list"}
        } as $tournament_weight_classes

        var $my_picked_weights {
          value = {}
        }

        foreach ($existing_picks) {
          each as $ep {
            conditional {
              if ($ep.membership_id == $on_clock_membership.id) {
                var.update $my_picked_weights {
                  value = $my_picked_weights|set:($ep.weight|to_text):true
                }
              }
            }
          }
        }

        var $chosen_weight_class_row {
          value = null
        }

        foreach ($tournament_weight_classes) {
          each as $wc {
            conditional {
              if ($chosen_weight_class_row == null && ($my_picked_weights|has:($wc.weight|to_text)) == false) {
                var.update $chosen_weight_class_row {
                  value = $wc
                }
              }
            }
          }
        }

        precondition ($chosen_weight_class_row != null) {
          error = "This member already has a pick at every weight in this tournament."
        }

        var.update $chosen_weight {
          value = $chosen_weight_class_row.weight
        }

        db.query wrestler {
          where = $db.wrestler.tournament_id == $week.linked_tournament_id && $db.wrestler.weight_class_id == $chosen_weight_class_row.id
          sort = {wrestler.seed: "asc"}
          return = {type: "list"}
        } as $weight_entries

        foreach ($weight_entries) {
          each as $entry {
            conditional {
              if ($chosen_wrestler_id == null && $entry.canonical_wrestler_id != null && ($drafted_wrestler_map|has:($entry.canonical_wrestler_id|to_text)) == false) {
                var.update $chosen_wrestler_id {
                  value = $entry.canonical_wrestler_id
                }
              }
            }
          }
        }

        precondition ($chosen_wrestler_id != null) {
          error = "No linkable, undrafted wrestler found at " ~ ($chosen_weight|to_text) ~ " in this tournament's field."
        }
      }

      else {
        conditional {
          if ($round_number <= $league.roster_starter_slots) {
            var.update $slot_type {
              value = "starter"
            }
          }
        }

        db.query season_weight_class {
          where = $db.season_weight_class.season_id == $league.season_id
          sort = {season_weight_class.weight: "asc"}
          return = {type: "list"}
        } as $weight_classes

        conditional {
          if ($slot_type == "starter") {
            foreach ($weight_classes) {
              each as $wc {
                conditional {
                  if ($chosen_season_weight_class_id == null) {
                    db.query roster_slot {
                      where = $db.roster_slot.league_id == $league.id && $db.roster_slot.membership_id == $on_clock_membership.id && $db.roster_slot.season_weight_class_id == $wc.id && $db.roster_slot.slot_type == "starter" && $db.roster_slot.status == "active"
                      return = {type: "exists"}
                    } as $filled

                    conditional {
                      if ($filled == false) {
                        var.update $chosen_season_weight_class_id {
                          value = $wc.id
                        }

                        var.update $chosen_weight {
                          value = $wc.weight
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          else {
            var $first_wc {
              value = $weight_classes|slice:0:1|first
            }

            var.update $chosen_season_weight_class_id {
              value = $first_wc.id
            }

            var.update $chosen_weight {
              value = $first_wc.weight
            }

            db.query roster_slot {
              where = $db.roster_slot.league_id == $league.id && $db.roster_slot.membership_id == $on_clock_membership.id && $db.roster_slot.slot_type == "alternate" && $db.roster_slot.status == "active"
              return = {type: "list"}
            } as $existing_alternates

            var.update $slot_index {
              value = ($existing_alternates|count) + 1
            }
          }
        }

        precondition ($chosen_season_weight_class_id != null) {
          error = "Could not find an open weight class to autopick into."
        }

        db.query canonical_wrestler {
          sort = {canonical_wrestler.id: "asc"}
          return = {type: "list", paging: {page: 1, per_page: 500}}
        } as $candidate_page

        foreach ($candidate_page.items) {
          each as $candidate {
            conditional {
              if ($chosen_wrestler_id == null && ($drafted_wrestler_map|has:($candidate.id|to_text)) == false) {
                var.update $chosen_wrestler_id {
                  value = $candidate.id
                }
              }
            }
          }
        }

        precondition ($chosen_wrestler_id != null) {
          error = "Could not find an undrafted wrestler in the first 500 candidates."
        }
      }
    }

    db.add draft_pick {
      data = {
        created_at            : now
        draft_id              : $draft.id
        league_id             : $league.id
        membership_id         : $on_clock_membership.id
        canonical_wrestler_id : $chosen_wrestler_id
        overall_pick_number   : $draft.current_pick_number
        round_number          : $round_number
        season_weight_class_id: $chosen_season_weight_class_id
        weight                : $chosen_weight
        pick_type             : "autopick"
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
            membership_id          : $on_clock_membership.id
            canonical_wrestler_id  : $chosen_wrestler_id
            season_weight_class_id : $chosen_season_weight_class_id
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
  guid = "kAlLe9W1jLKqoMeNLRAkOTDK9Lc"
}

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

    // Only autopick wrestlers who actually rostered for THIS league's own
    // season - same reasoning as the manual pick/waiver endpoints.
    db.get season {
      field_name = "id"
      field_value = $league.season_id
    } as $autopick_season

    function.run season_label_from_year {
      input = {year: $autopick_season.year}
    } as $autopick_season_label

    db.query canonical_wrestler_team {
      where = $db.canonical_wrestler_team.season_label == $autopick_season_label
      return = {type: "list", paging: {page: 1, per_page: 50000}}
    } as $autopick_roster_rows

    var $autopick_season_roster_map {
      value = {}
    }

    foreach ($autopick_roster_rows.items) {
      each as $sr {
        var.update $autopick_season_roster_map {
          value = $autopick_season_roster_map|set:($sr.canonical_wrestler_id|to_text):true
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
            conditional {
              if ($league.roster_alternate_mode == "flat_pool") {
                // flat_pool: no per-weight cap, so any weight class works as
                // long as it still has an undrafted, rostered candidate -
                // just always picking weight_classes[0] would eventually
                // fail outright once THAT weight's real candidate pool ran
                // dry, even with plenty of room left in the flat pool.
                db.query roster_slot {
                  where = $db.roster_slot.league_id == $league.id && $db.roster_slot.membership_id == $on_clock_membership.id && $db.roster_slot.slot_type == "alternate" && $db.roster_slot.status == "active"
                  return = {type: "list"}
                } as $team_alternates_flat

                foreach ($weight_classes) {
                  each as $wc3 {
                    conditional {
                      if ($chosen_season_weight_class_id == null) {
                        var $wc3_weight_text {
                          value = ($wc3.weight|to_text)
                        }

                        db.query canonical_wrestler {
                          where = $db.canonical_wrestler.current_weight_class == $wc3_weight_text
                          sort = {canonical_wrestler.id: "asc"}
                          return = {type: "list", paging: {page: 1, per_page: 500}}
                        } as $wc3_candidates

                        var $wc3_has_candidate {
                          value = false
                        }

                        foreach ($wc3_candidates.items) {
                          each as $wc3_cand {
                            var $wc3_cand_key {
                              value = ($wc3_cand.id|to_text)
                            }

                            conditional {
                              if (($drafted_wrestler_map|has:$wc3_cand_key) == false && ($autopick_season_roster_map|has:$wc3_cand_key)) {
                                var.update $wc3_has_candidate {
                                  value = true
                                }
                              }
                            }
                          }
                        }

                        conditional {
                          if ($wc3_has_candidate) {
                            var.update $chosen_season_weight_class_id {
                              value = $wc3.id
                            }

                            var.update $chosen_weight {
                              value = $wc3.weight
                            }

                            var.update $slot_index {
                              value = ($team_alternates_flat|count) + 1
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
              else {
                // per_weight - find this team's first weight that doesn't
                // already have a full set of alternates yet, the same way
                // the starter branch above finds the first open starter
                // weight. The old version always chose weight_classes[0]
                // outright, so every alternate round for every team piled
                // up at the season's first weight class regardless of
                // whether it already had one.
                foreach ($weight_classes) {
                  each as $wc2 {
                    conditional {
                      if ($chosen_season_weight_class_id == null) {
                        db.query roster_slot {
                          where = $db.roster_slot.league_id == $league.id && $db.roster_slot.membership_id == $on_clock_membership.id && $db.roster_slot.season_weight_class_id == $wc2.id && $db.roster_slot.slot_type == "alternate" && $db.roster_slot.status == "active"
                          return = {type: "list"}
                        } as $wc_alternates

                        conditional {
                          if (($wc_alternates|count) < $league.roster_alternate_slots) {
                            var.update $chosen_season_weight_class_id {
                              value = $wc2.id
                            }

                            var.update $chosen_weight {
                              value = $wc2.weight
                            }

                            var.update $slot_index {
                              value = ($wc_alternates|count) + 1
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        precondition ($chosen_season_weight_class_id != null) {
          error = "Could not find an open weight class to autopick into."
        }

        // Must actually compete at the weight the slot being filled is for -
        // this endpoint used to pick the lowest-id undrafted wrestler
        // regardless of weight, which is how the whole demo league ended up
        // with e.g. a 174lb wrestler sitting in a 125lb slot.
        var $chosen_weight_text {
          value = ($chosen_weight|to_text)
        }

        db.query canonical_wrestler {
          where = $db.canonical_wrestler.current_weight_class == $chosen_weight_text
          sort = {canonical_wrestler.id: "asc"}
          return = {type: "list", paging: {page: 1, per_page: 500}}
        } as $candidate_page

        foreach ($candidate_page.items) {
          each as $candidate {
            var $autopick_candidate_key {
              value = ($candidate.id|to_text)
            }

            conditional {
              if ($chosen_wrestler_id == null && ($drafted_wrestler_map|has:$autopick_candidate_key) == false && ($autopick_season_roster_map|has:$autopick_candidate_key)) {
                var.update $chosen_wrestler_id {
                  value = $candidate.id
                }
              }
            }
          }
        }

        precondition ($chosen_wrestler_id != null) {
          error = "Could not find an undrafted wrestler at " ~ $chosen_weight_text ~ " lbs in the first 500 candidates at that weight."
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

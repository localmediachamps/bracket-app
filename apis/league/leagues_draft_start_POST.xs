// Owner/commissioner starts a draft: shuffles active members into a random
// draft_position, materializes the round-1 snake order, and opens pick 1.
// Same endpoint handles both contexts (same draft engine, same draft room UI):
//   - season_week_id omitted -> the one-time preseason league draft.
//   - season_week_id set -> a tournament-only mini-draft scoped to that
//     week's linked tournament (one wrestler per weight, no alternates,
//     never touches roster_slot - see tables/draft_pick.xs).
// v1 ships without enforced pick timers (pick_time_limit_seconds stays null
// unless league.draft_config sets one) - see the fantasy league plan's open
// question #2 on autopick-on-timeout, deferred until real usage shows it's needed.
query "leagues/draft/start" verb=POST {
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

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id
      return = {type: "single"}
    } as $my_membership

    precondition ($my_membership != null && $my_membership.status == "active" && ($my_membership.role == "owner" || $my_membership.role == "commissioner")) {
      error_type = "accessdenied"
      error = "Only the league owner or a commissioner can start a draft."
    }

    var $is_tournament_draft {
      value = ($input.season_week_id != null)
    }

    var $season_week {
      value = null
    }

    var $rounds {
      value = null
    }

    conditional {
      if ($is_tournament_draft) {
        precondition ($league.status == "active") {
          error_type = "inputerror"
          error = "The league must have finished its preseason draft before running a tournament mini-draft."
        }

        db.get season_week {
          field_name = "id"
          field_value = $input.season_week_id
        } as $week

        precondition ($week != null && $week.season_id == $league.season_id) {
          error_type = "inputerror"
          error = "That week isn't part of this league's season."
        }

        precondition ($week.week_type == "regular_season_tournament" || $week.week_type == "bowl" || $week.week_type == "nationals") {
          error_type = "inputerror"
          error = "This isn't a tournament week."
        }

        precondition ($week.tournament_game_mode == "tournament_draft") {
          error_type = "inputerror"
          error = "This week isn't configured for a tournament mini-draft."
        }

        precondition ($week.linked_tournament_id != null) {
          error_type = "inputerror"
          error = "This week has no linked tournament yet."
        }

        db.query weight_class {
          where = $db.weight_class.tournament_id == $week.linked_tournament_id
          return = {type: "list"}
        } as $tournament_weight_classes

        precondition (($tournament_weight_classes|count) > 0) {
          error_type = "inputerror"
          error = "The linked tournament has no weight classes set up yet."
        }

        var.update $season_week {
          value = $week
        }

        var.update $rounds {
          value = $tournament_weight_classes|count
        }
      }

      else {
        precondition ($league.status == "forming") {
          error_type = "inputerror"
          error = "This league's preseason draft has already been started or completed."
        }

        // roster_alternate_slots is PER weight class (a bench/backup slot at
        // every weight), not a flat total - total rounds = starters + one
        // round per weight per alternate slot.
        db.query season_weight_class {
          where = $db.season_weight_class.season_id == $league.season_id
          return = {type: "list"}
        } as $preseason_weight_classes

        var.update $rounds {
          value = $league.roster_starter_slots + ($league.roster_alternate_slots * ($preseason_weight_classes|count))
        }
      }
    }

    // "One draft per (league, week-context)" is app-enforced, not a DB
    // unique index (season_week_id nullability - see tables/draft.xs)
    db.query draft {
      where = $db.draft.league_id == $league.id && (($input.season_week_id == null && $db.draft.season_week_id == null) || $db.draft.season_week_id == $input.season_week_id)
      return = {type: "exists"}
    } as $existing_draft

    precondition ($existing_draft == false) {
      error_type = "inputerror"
      error = "A draft already exists for this league/week."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.status == "active"
      return = {type: "list"}
    } as $members

    var $member_count {
      value = $members|count
    }

    precondition ($member_count >= 2) {
      error_type = "inputerror"
      error = "A league needs at least 2 active members to start a draft."
    }

    // Real tournaments don't have their entrants finalized until coaches'
    // roster registrations are in and the tournament directors have set
    // seeds/brackets - typically just days before the event, well after a
    // commissioner might configure this week. Block starting the mini-draft
    // until every weight class actually has enough linkable entrants for
    // every member to get a distinct pick there.
    conditional {
      if ($is_tournament_draft) {
        db.query weight_class {
          where = $db.weight_class.tournament_id == $season_week.linked_tournament_id
          return = {type: "list"}
        } as $check_weight_classes

        var $understaffed_weight {
          value = null
        }

        foreach ($check_weight_classes) {
          each as $wc {
            conditional {
              if ($understaffed_weight == null) {
                db.query wrestler {
                  where = $db.wrestler.tournament_id == $season_week.linked_tournament_id && $db.wrestler.weight_class_id == $wc.id && $db.wrestler.canonical_wrestler_id != null
                  return = {type: "list"}
                } as $entrants

                conditional {
                  if (($entrants|count) < $member_count) {
                    var.update $understaffed_weight {
                      value = $wc.weight
                    }
                  }
                }
              }
            }
          }
        }

        precondition ($understaffed_weight == null) {
          error_type = "inputerror"
          error = "Not enough registered, linked entrants yet at " ~ ($understaffed_weight|to_text) ~ " lbs for every member to get a pick there - wait until the tournament's full field and seeds are set, then try again."
        }
      }
    }

    // Random shuffle by repeated draw-without-replacement (avoids relying on
    // an array |sort with typed args - already flagged elsewhere in this
    // codebase as unreliable server-side).
    var $remaining {
      value = $members
    }

    var $snake_order {
      value = []
    }

    var $position {
      value = 1
    }

    while (($remaining|count) > 0) {
      each {
        var $remaining_count {
          value = $remaining|count
        }

        security.random_number {
          min = 0
          max = ($remaining_count - 1)
        } as $draw_idx

        var $drawn {
          value = $remaining|slice:$draw_idx:1|first
        }

        array.push $snake_order {
          value = $drawn.id
        }

        conditional {
          if ($is_tournament_draft == false) {
            db.edit league_membership {
              field_name = "id"
              field_value = $drawn.id
              data = {draft_position: $position}
            } as $updated_membership
          }
        }

        math.add $position {
          value = 1
        }

        var $before {
          value = $remaining|slice:0:$draw_idx
        }

        var $after_start {
          value = $draw_idx + 1
        }

        var $after {
          value = $remaining|slice:$after_start:($remaining_count - $after_start)
        }

        array.merge $before {
          value = $after
        }

        var.update $remaining {
          value = $before
        }
      }
    }

    var $first_membership_id {
      value = $snake_order|slice:0:1|first
    }

    var $member_user_ids {
      value = []
    }

    foreach ($members) {
      each as $m2 {
        array.push $member_user_ids {
          value = $m2.user_id
        }
      }
    }

    db.add draft {
      data = {
        created_at             : now
        league_id              : $league.id
        season_week_id          : $input.season_week_id
        status                 : "in_progress"
        scheduled_at           : now
        current_pick_number    : 1
        current_membership_id  : $first_membership_id
        rounds                 : $rounds
        pick_time_limit_seconds: null
        snake_order            : $snake_order
      }
    } as $draft

    var $league_updated {
      value = $league
    }

    conditional {
      if ($is_tournament_draft == false) {
        db.edit league {
          field_name = "id"
          field_value = $league.id
          data = {status: "drafting", updated_at: now}
        } as $preseason_league_updated

        var.update $league_updated {
          value = $preseason_league_updated
        }
      }
    }

    function.run notify {
      input = {
        user_ids: $member_user_ids
        type    : $is_tournament_draft ? "tournament_draft_starting" : "draft_starting"
        title   : $is_tournament_draft ? ("The tournament draft for " ~ $league.name ~ " has started!") : ("The draft for " ~ $league.name ~ " has started!")
        data    : {league_id: $league.id, draft_id: $draft.id, season_week_id: $input.season_week_id}
      }
    } as $notify_result
  }

  response = {draft: $draft, league: $league_updated}
  guid = "jJJ8zc2MpAX6tV0D6Emc5Rq7ueo"
}

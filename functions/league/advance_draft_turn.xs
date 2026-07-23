// Called right after a draft_pick (and, for the preseason draft only, a
// roster_slot) is written - manual or autopick - before
// draft.current_pick_number has been incremented. Advances the snake-draft
// turn to the next picker, or completes the draft if the just-made pick was
// the last one. A tournament mini-draft (draft.season_week_id set) completing
// does NOT touch league.status - the season-long league stays "active"
// throughout, only that one week's mini-draft finishes.
//
// FIXED 2026-07-23: this function's own function.run calls to notify()
// previously used a ternary directly in the `type`/`title` input fields
// plus a `data` object literal containing a null member (season_week_id) -
// that combination threw a fatal "Invalid name: X" error every time this
// function actually ran (confirmed: the exact same notify() call pattern
// works fine when called directly from a top-level query, e.g.
// leagues_draft_start_POST.xs - this only broke one function.run layer
// deeper, from inside another function). This silently blocked every
// preseason draft pick (manual or autopick) from ever completing - draft/
// pick and draft/autopick both call this function after every single pick.
// Confirmed via bisection while running the first real demo-league draft.
// Fix: precompute type/title into plain vars before calling notify, and
// drop the data payload (deep-link data, not essential).
function advance_draft_turn {
  input {
    int draft_id
  }

  stack {
    db.get draft {
      field_name = "id"
      field_value = $input.draft_id
    } as $draft

    db.get league {
      field_name = "id"
      field_value = $draft.league_id
    } as $league

    var $is_tournament_draft {
      value = ($draft.season_week_id != null)
    }

    var $member_count {
      value = $draft.snake_order|count
    }

    var $next_pick_number {
      value = $draft.current_pick_number + 1
    }

    var $total_picks {
      value = $member_count * $draft.rounds
    }

    var $draft_updated {
      value = null
    }

    conditional {
      if ($next_pick_number > $total_picks) {
        db.edit draft {
          field_name = "id"
          field_value = $draft.id
          data = {status: "complete", current_pick_number: $next_pick_number, current_membership_id: null}
        } as $completed_draft

        conditional {
          if ($is_tournament_draft == false) {
            db.edit league {
              field_name = "id"
              field_value = $league.id
              data = {status: "active", updated_at: now}
            } as $league_reactivated
          }
        }

        var $complete_type { value = "draft_complete" }
        var $complete_title { value = "The draft for " ~ $league.name ~ " is complete!" }

        conditional {
          if ($is_tournament_draft) {
            var.update $complete_type { value = "tournament_draft_complete" }
            var.update $complete_title { value = "The tournament draft for " ~ $league.name ~ " is locked in!" }
          }
        }

        function.run notify {
          input = {
            user_id: $league.owner_id
            type   : $complete_type
            title  : $complete_title
          }
        } as $notify_complete

        var.update $draft_updated {
          value = $completed_draft
        }
      }

      else {
        var $round_number_next {
          value = ((($next_pick_number - 1) / $member_count)|floor) + 1
        }

        var $pick_in_round_next {
          value = ($next_pick_number - 1)|modulus:$member_count
        }

        var $next_index {
          value = $pick_in_round_next
        }

        conditional {
          if (($round_number_next|modulus:2) == 0) {
            var.update $next_index {
              value = ($member_count - 1) - $pick_in_round_next
            }
          }
        }

        var $next_membership_id {
          value = $draft.snake_order|slice:$next_index:1|first
        }

        db.edit draft {
          field_name = "id"
          field_value = $draft.id
          data = {current_pick_number: $next_pick_number, current_membership_id: $next_membership_id}
        } as $continued_draft

        db.get league_membership {
          field_name = "id"
          field_value = $next_membership_id
        } as $next_membership

        function.run notify {
          input = {
            user_id: $next_membership.user_id
            type   : "draft_your_turn"
            title  : "You're on the clock in " ~ $league.name
          }
        } as $notify_next

        var.update $draft_updated {
          value = $continued_draft
        }
      }
    }
  }

  response = $draft_updated
  guid = "qtaKkiFvjEtLsK51vsPVxhlcncc"
}

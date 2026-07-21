// Called right after a draft_pick (and, for the preseason draft only, a
// roster_slot) is written - manual or autopick - before
// draft.current_pick_number has been incremented. Advances the snake-draft
// turn to the next picker, or completes the draft if the just-made pick was
// the last one. A tournament mini-draft (draft.season_week_id set) completing
// does NOT touch league.status - the season-long league stays "active"
// throughout, only that one week's mini-draft finishes.
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

        function.run notify {
          input = {
            user_id: $league.owner_id
            type   : $is_tournament_draft ? "tournament_draft_complete" : "draft_complete"
            title  : $is_tournament_draft ? ("The tournament draft for " ~ $league.name ~ " is locked in!") : ("The draft for " ~ $league.name ~ " is complete!")
            data   : {league_id: $league.id, draft_id: $draft.id, season_week_id: $draft.season_week_id}
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
            type   : $is_tournament_draft ? "tournament_draft_your_turn" : "draft_your_turn"
            title  : "You're on the clock in " ~ $league.name
            data   : {league_id: $league.id, draft_id: $draft.id, season_week_id: $draft.season_week_id}
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

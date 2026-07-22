// Creates a dual_meet from real historical wrestler_match_history rows -
// used both for genuine historical backfill and for QA mock-season testing
// (create it with status="open" so test accounts can submit picks against
// real results that are simply hidden from the public API until the dual
// meet is locked/scored - see apis/brackets/dual_meets_id_GET.xs).
// The real result for every matched weight is stored immediately as the
// "answer key" on dual_meet_weight_slot; nothing here is randomly generated.
query "admin/dual-meets/from-history" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Must exactly match wrestler_match_history.winner_school_raw /
    // loser_school_raw text for one side of the meet
    text home_team_name filters=trim

    // The other side
    text away_team_name filters=trim

    // Exact occurred_at timestamp of the real historical dual meet to pull
    timestamp occurred_at

    int year

    // Optional display name - defaults to "{away} at {home}"
    text? name? filters=trim

    // Prediction deadline - defaults to null (open indefinitely until
    // manually locked, useful for QA where "now" is after the real date)
    timestamp? locks_at?

    // draft | open | locked | scoring | completed | cancelled - default open
    text? status? filters=trim|lower
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.query wrestler_match_history {
      where = $db.wrestler_match_history.event_type == "dual" && $db.wrestler_match_history.occurred_at == $input.occurred_at && (($db.wrestler_match_history.winner_school_raw == $input.home_team_name && $db.wrestler_match_history.loser_school_raw == $input.away_team_name) || ($db.wrestler_match_history.winner_school_raw == $input.away_team_name && $db.wrestler_match_history.loser_school_raw == $input.home_team_name))
      return = {type: "list"}
    } as $matches

    precondition (($matches|count) > 0) {
      error_type = "notfound"
      error = "No historical dual meet found for these teams and date."
    }

    var $display_name {
      value = $input.name
    }

    conditional {
      if ($display_name == null || ($display_name|strlen) == 0) {
        var.update $display_name {
          value = $input.away_team_name ~ " at " ~ $input.home_team_name
        }
      }
    }

    var $dm_status {
      value = ($input.status)|first_notempty:"open"
    }

    // Resolve a unique slug (slugify(name year), -2, -3, ...)
    function.run slugify {
      input = {text: $display_name ~ " " ~ ($input.year|to_text)}
    } as $slug_base

    var $slug {
      value = $slug_base
    }

    var $slug_suffix {
      value = 1
    }

    var $slug_taken {
      value = true
    }

    while (`$slug_taken`) {
      each {
        db.query dual_meet {
          where = $db.dual_meet.slug == $slug
          return = {type: "count"}
        } as $slug_hits

        conditional {
          if ($slug_hits == 0) {
            var.update $slug_taken {
              value = false
            }
          }
          else {
            math.add $slug_suffix {
              value = 1
            }

            var.update $slug {
              value = $slug_base ~ "-" ~ ($slug_suffix|to_text)
            }
          }
        }
      }
    }

    db.add dual_meet {
      data = {
        created_at      : now
        name            : $display_name
        year            : $input.year
        slug            : $slug
        home_team_name  : $input.home_team_name
        away_team_name  : $input.away_team_name
        occurred_at     : $input.occurred_at
        locks_at        : $input.locks_at
        status          : $dm_status
        visibility      : "public"
        created_by      : $auth.id
        entry_count     : 0
        source_match_key: $input.home_team_name ~ "_" ~ $input.away_team_name ~ "_" ~ ($input.occurred_at|to_text)
      }
    } as $dual_meet

    var $slots {
      value = []
    }

    foreach ($matches) {
      each as $m {
        var $weight_num {
          value = $m.weight_class|to_int
        }

        var $winner_is_home {
          value = $m.winner_school_raw == $input.home_team_name
        }

        var $home_wrestler {
          value = null
        }

        var $away_wrestler {
          value = null
        }

        var $winner_side {
          value = "away"
        }

        conditional {
          if ($winner_is_home) {
            var.update $home_wrestler {
              value = $m.winner_name_raw
            }

            var.update $away_wrestler {
              value = $m.loser_name_raw
            }

            var.update $winner_side {
              value = "home"
            }
          }
          else {
            var.update $away_wrestler {
              value = $m.winner_name_raw
            }

            var.update $home_wrestler {
              value = $m.loser_name_raw
            }
          }
        }

        function.run normalize_victory_type {
          input = {raw: $m.victory_type}
        } as $normalized_vt

        db.add dual_meet_weight_slot {
          data = {
            created_at         : now
            dual_meet_id       : $dual_meet.id
            weight             : $weight_num
            display_order      : $weight_num
            home_wrestler_name : $home_wrestler
            away_wrestler_name : $away_wrestler
            actual_winner_side : $winner_side
            actual_victory_type: $normalized_vt
            occurred           : true
          }
        } as $slot

        array.push $slots {
          value = $slot
        }
      }
    }

    var $sorted_slots {
      value = $slots|sort:"weight":"number"
    }
  }

  response = {dual_meet: $dual_meet, weight_slots: $sorted_slots}
  guid = "Nx4pTqLw8HbYoZmVsRc3KgD6jFe"
}

// Public dual meet detail with its weight slots. The real result
// (actual_winner_side/actual_victory_type/occurred) is only ever included
// once the dual meet is completed - while open/locked, users see just the
// matchup (teams + wrestler names if known), never the answer key, so
// predicting stays meaningful even when the underlying data was backfilled
// from real history for testing.
query "dual-meets/{id}" verb=GET {
  api_group = "brackets"

  input {
    // Dual meet id or slug
    text id
  }

  stack {
    var $dm_id {
      value = $input.id|to_int
    }

    var $dual_meet {
      value = null
    }

    conditional {
      if ($dm_id > 0) {
        db.get dual_meet {
          field_name = "id"
          field_value = $dm_id
        } as $by_id

        var.update $dual_meet {
          value = $by_id
        }
      }
    }

    conditional {
      if ($dual_meet == null) {
        db.get dual_meet {
          field_name = "slug"
          field_value = $input.id
        } as $by_slug

        var.update $dual_meet {
          value = $by_slug
        }
      }
    }

    precondition ($dual_meet != null) {
      error_type = "notfound"
      error = "Dual meet not found."
    }

    var $reveal {
      value = $dual_meet.status == "completed"
    }

    db.query dual_meet_weight_slot {
      where = $db.dual_meet_weight_slot.dual_meet_id == $dual_meet.id
      sort = {dual_meet_weight_slot.display_order: "asc"}
      return = {type: "list"}
    } as $slots

    var $slot_out {
      value = []
    }

    foreach ($slots) {
      each as $s {
        var $row {
          value = {
            id                : $s.id
            weight            : $s.weight
            display_order     : $s.display_order
            home_wrestler_name: $s.home_wrestler_name
            away_wrestler_name: $s.away_wrestler_name
          }
        }

        conditional {
          if ($reveal) {
            var.update $row {
              value = $row
                |set:"actual_winner_side":$s.actual_winner_side
                |set:"actual_victory_type":$s.actual_victory_type
                |set:"occurred":$s.occurred
            }
          }
        }

        array.push $slot_out {
          value = $row
        }
      }
    }
  }

  response = {
    id                    : $dual_meet.id
    name                  : $dual_meet.name
    slug                  : $dual_meet.slug
    year                  : $dual_meet.year
    home_team_name        : $dual_meet.home_team_name
    away_team_name        : $dual_meet.away_team_name
    home_canonical_team_id: $dual_meet.home_canonical_team_id
    away_canonical_team_id: $dual_meet.away_canonical_team_id
    occurred_at           : $dual_meet.occurred_at
    locks_at              : $dual_meet.locks_at
    status                : $dual_meet.status
    entry_count           : $dual_meet.entry_count
    is_historical         : $dual_meet.is_historical
    home_score            : ($reveal ? $dual_meet.home_score : null)
    away_score            : ($reveal ? $dual_meet.away_score : null)
    weight_slots          : $slot_out
  }
  guid = "mqrNHKmFENqw4icEx39EwsdFYFM"
}

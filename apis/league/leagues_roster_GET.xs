// Any active member's current roster - visible to other active league
// members (normal fantasy-league transparency), used by the trade proposal
// UI to show what a prospective trade partner owns.
query "leagues/roster" verb=GET {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int membership_id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $input.league_id && $db.league_membership.user_id == $auth.id && $db.league_membership.status == "active"
      return = {type: "exists"}
    } as $is_member

    precondition ($is_member) {
      error_type = "accessdenied"
      error = "You are not an active member of this league."
    }

    db.get league {
      field_name = "id"
      field_value = $input.league_id
    } as $league

    db.get season {
      field_name = "id"
      field_value = $league.season_id
    } as $roster_season

    db.query roster_slot {
      where = $db.roster_slot.league_id == $input.league_id && $db.roster_slot.membership_id == $input.membership_id && $db.roster_slot.status == "active"
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
          output = ["id", "display_name"]
        } as $wrestler

        function.run get_wrestler_record_summary {
          input = {canonical_wrestler_id: $r.canonical_wrestler_id}
        } as $record

        // Same "quick stats" card the waiver wire and rankings show - lets
        // the trade UI show research context for both sides of a proposal,
        // not just the wrestler's name.
        function.run build_wrestler_competition_card {
          input = {canonical_wrestler_id: $r.canonical_wrestler_id, season_year: $roster_season.year}
        } as $competition_card

        var $slot_weight {
          value = null
        }

        conditional {
          if ($r.season_weight_class_id != null) {
            db.get season_weight_class {
              field_name = "id"
              field_value = $r.season_weight_class_id
            } as $swc

            var.update $slot_weight {
              value = $swc|get:"weight":null
            }
          }
        }

        array.push $roster_rows {
          value = {
            roster_slot_id       : $r.id
            wrestler              : $wrestler
            record                : $record
            slot_type             : $r.slot_type
            season_weight_class_id: $r.season_weight_class_id
            weight                : $slot_weight
            competition_card      : $competition_card
          }
        }
      }
    }
  }

  response = $roster_rows
  guid = "2HQGsuqvj1P7oC_GIVaVycFztGc"
}

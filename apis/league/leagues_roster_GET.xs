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

        array.push $roster_rows {
          value = {
            roster_slot_id: $r.id
            wrestler      : $wrestler
            slot_type     : $r.slot_type
          }
        }
      }
    }
  }

  response = $roster_rows
  guid = "2HQGsuqvj1P7oC_GIVaVycFztGc"
}

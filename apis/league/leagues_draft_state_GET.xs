// Draft room state: the draft row, every pick made so far (with wrestler +
// weight info), and every league member with their draft_position - enough
// for a client to render the board and know whose turn it is without a
// separate call. Same endpoint serves both the preseason draft
// (season_week_id omitted) and a tournament mini-draft (season_week_id set).
// Requires active league membership.
query "leagues/draft/state" verb=GET {
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

    precondition ($my_membership != null && $my_membership.status == "active") {
      error_type = "accessdenied"
      error = "You must be an active member of this league to view the draft."
    }

    db.query draft {
      where = $db.draft.league_id == $league.id && (($input.season_week_id == null && $db.draft.season_week_id == null) || $db.draft.season_week_id == $input.season_week_id)
      return = {type: "single"}
    } as $draft

    precondition ($draft != null) {
      error_type = "notfound"
      error = "This draft doesn't exist yet."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.status == "active"
      sort = {league_membership.draft_position: "asc"}
      return = {type: "list"}
    } as $members

    var $member_rows {
      value = []
    }

    foreach ($members) {
      each as $m {
        db.get user {
          field_name = "id"
          field_value = $m.user_id
          output = ["id", "username", "display_name", "avatar_url"]
        } as $member_user

        array.push $member_rows {
          value = {
            membership_id : $m.id
            user          : $member_user
            draft_position: $m.draft_position
            is_current    : ($m.id == $draft.current_membership_id)
          }
        }
      }
    }

    db.query draft_pick {
      where = $db.draft_pick.draft_id == $draft.id
      sort = {draft_pick.overall_pick_number: "asc"}
      return = {type: "list"}
    } as $picks

    var $pick_rows {
      value = []
    }

    foreach ($picks) {
      each as $p {
        db.get canonical_wrestler {
          field_name = "id"
          field_value = $p.canonical_wrestler_id
          output = ["id", "display_name", "current_team_id"]
        } as $wrestler

        array.push $pick_rows {
          value = {
            overall_pick_number: $p.overall_pick_number
            round_number       : $p.round_number
            membership_id      : $p.membership_id
            wrestler           : $wrestler
            weight             : $p.weight
            pick_type          : $p.pick_type
            picked_at          : $p.picked_at
          }
        }
      }
    }

    var $total_picks {
      value = ($members|count) * $draft.rounds
    }
  }

  response = {
    draft      : $draft
    members    : $member_rows
    picks      : $pick_rows
    total_picks: $total_picks
  }
  guid = "RshAxRdELEUxpw_tAbmKeStHeb8"
}

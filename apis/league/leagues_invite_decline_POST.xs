// Decline a pending league invite.
query "leagues/invite/decline" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int league_id
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
    } as $membership

    precondition ($membership != null && $membership.status == "invited") {
      error_type = "inputerror"
      error = "You don't have a pending invite to this league."
    }

    db.edit league_membership {
      field_name = "id"
      field_value = $membership.id
      data = {status: "removed"}
    } as $declined
  }

  response = {ok: true}
  guid = "osZh_FTPC9vBd55lzZNwzKUVe08"
}

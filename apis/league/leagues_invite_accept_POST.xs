// Accept a pending league invite. Only the invited user's own account can
// accept - having the league id alone isn't enough (no open/public join).
query "leagues/invite/accept" verb=POST {
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

    precondition ($league.member_limit == null || $league.member_count < $league.member_limit) {
      error_type = "inputerror"
      error = "This league is full."
    }

    db.edit league_membership {
      field_name = "id"
      field_value = $membership.id
      data = {status: "active", joined_at: now}
    } as $accepted

    db.edit league {
      field_name = "id"
      field_value = $league.id
      data = {member_count: ($league.member_count + 1)}
    } as $league_updated

    conditional {
      if ($league.owner_id != $auth.id) {
        db.get user {
          field_name = "id"
          field_value = $auth.id
          output = ["id", "name", "display_name", "username"]
        } as $joiner

        var $joiner_name {
          value = $joiner.display_name|first_notempty:$joiner.name
        }

        function.run notify {
          input = {
            user_id: $league.owner_id
            type   : "league_invite_accepted"
            title  : $joiner_name ~ " joined " ~ $league.name
            data   : {league_id: $league.id}
          }
        } as $notify_result
      }
    }
  }

  response = {league: $league_updated, membership: $accepted}
  guid = "JDlkeJkzZxNgilfJTTgO7hhHsSE"
}

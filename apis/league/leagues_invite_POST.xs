// Invite a specific existing Mat Savvy account to a league (owner or
// commissioner only). Per the confirmed game design, leagues are invite-only
// by account - there is no open/public join. Creates (or reactivates) a
// league_membership row with status=invited; the invited user must accept
// via leagues_invite_accept_POST before they count as an active member.
query "leagues/invite" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int league_id

    // Existing user to invite
    int invited_user_id
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
      error = "Only the league owner or a commissioner can send invites."
    }

    db.get user {
      field_name = "id"
      field_value = $input.invited_user_id
    } as $invited_user

    precondition ($invited_user != null) {
      error_type = "notfound"
      error = "User not found."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $input.invited_user_id
      return = {type: "single"}
    } as $existing_membership

    precondition ($existing_membership == null || ($existing_membership.status != "active" && $existing_membership.status != "invited")) {
      error_type = "inputerror"
      error = "This user is already a member of or already invited to this league."
    }

    precondition ($league.member_limit == null || $league.member_count < $league.member_limit) {
      error_type = "inputerror"
      error = "This league is full."
    }

    var $membership {
      value = null
    }

    conditional {
      if ($existing_membership != null) {
        db.edit league_membership {
          field_name = "id"
          field_value = $existing_membership.id
          data = {status: "invited", role: "member"}
        } as $reinvited

        var.update $membership {
          value = $reinvited
        }
      }

      else {
        db.add league_membership {
          data = {
            created_at: now
            league_id : $league.id
            user_id   : $input.invited_user_id
            role      : "member"
            status    : "invited"
          }
        } as $new_membership

        var.update $membership {
          value = $new_membership
        }
      }
    }

    function.run notify {
      input = {
        user_id: $input.invited_user_id
        type   : "league_invite"
        title  : "You've been invited to join " ~ $league.name
        data   : {league_id: $league.id}
      }
    } as $notify_result
  }

  response = $membership
  guid = "iBV1rzqAHWZF11ZXhTJvpz2zFKg"
}

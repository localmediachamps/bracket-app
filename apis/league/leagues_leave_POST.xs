// Leave a league. An owner leaving with other active members transfers
// ownership to the earliest-joined remaining member; the last active member
// leaving deletes the league (and all of its memberships).
query "leagues/{id}/leave" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    // League id
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get league {
      field_name = "id"
      field_value = $input.id
    } as $league

    precondition ($league != null) {
      error_type = "notfound"
      error = "League not found."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id
      return = {type: "single"}
    } as $membership

    precondition ($membership != null && $membership.status == "active") {
      error_type = "inputerror"
      error = "You are not an active member of this league."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.status == "active" && $db.league_membership.user_id != $auth.id
      sort = {league_membership.joined_at: "asc"}
      return = {type: "list"}
    } as $others

    var $others_count {
      value = $others|count
    }

    var $deleted {
      value = false
    }

    var $new_owner_id {
      value = null
    }

    conditional {
      if ($membership.role == "owner" && $others_count == 0) {
        db.query league_membership {
          where = $db.league_membership.league_id == $league.id
          return = {type: "list"}
        } as $all_memberships

        foreach ($all_memberships) {
          each as $lm {
            db.del league_membership {
              field_name = "id"
              field_value = $lm.id
            }
          }
        }

        db.del league {
          field_name = "id"
          field_value = $league.id
        }

        var.update $deleted {
          value = true
        }
      }

      elseif ($membership.role == "owner") {
        var $heir {
          value = $others|first
        }

        db.edit league_membership {
          field_name = "id"
          field_value = $heir.id
          data = {role: "owner"}
        } as $heir_updated

        db.edit league_membership {
          field_name = "id"
          field_value = $membership.id
          data = {status: "removed"}
        } as $departed

        db.edit league {
          field_name = "id"
          field_value = $league.id
          data = {
            owner_id    : $heir.user_id
            member_count: ($league.member_count - 1)
          }
        } as $league_updated

        var.update $new_owner_id {
          value = $heir.user_id
        }
      }

      else {
        db.edit league_membership {
          field_name = "id"
          field_value = $membership.id
          data = {status: "removed"}
        } as $departed_member

        db.edit league {
          field_name = "id"
          field_value = $league.id
          data = {member_count: ($league.member_count - 1)}
        } as $league_updated_member
      }
    }
  }

  response = {
    ok          : true
    deleted     : $deleted
    new_owner_id: $new_owner_id
  }
  guid = "PiF6_2jaUmb1GuslsDb_lIkIQrI"
}

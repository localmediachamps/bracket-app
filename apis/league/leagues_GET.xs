// "My leagues" - every league the caller has an active or pending-invited
// membership in. There's no public discovery list (leagues are invite-only).
query leagues verb=GET {
  api_group = "league"
  auth = "user"

  input {
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.query league_membership {
      where = $db.league_membership.user_id == $auth.id && ($db.league_membership.status == "active" || $db.league_membership.status == "invited")
      sort = {league_membership.created_at: "desc"}
      return = {type: "list"}
    } as $memberships

    var $rows {
      value = []
    }

    foreach ($memberships) {
      each as $m {
        db.get league {
          field_name = "id"
          field_value = $m.league_id
        } as $league_row

        array.push $rows {
          value = {
            league    : $league_row
            role      : $m.role
            status    : $m.status
            wins      : $m.wins
            losses    : $m.losses
            points_for: $m.points_for
          }
        }
      }
    }
  }

  response = $rows
  guid = "7we0vTODjCo0rOQSfrGJAmE8x7g"
}

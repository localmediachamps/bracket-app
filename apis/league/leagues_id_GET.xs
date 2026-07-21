// League detail. Leagues are private/unlisted only (no public browsing), so
// the full detail including members requires an active or invited
// membership, ownership, or site admin - unlike fantasy_group there's no
// "public" privacy tier that opens this up to everyone.
query "leagues/{id}" verb=GET {
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
    } as $my_membership

    db.get user {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "is_admin"]
    } as $requester

    var $is_site_admin {
      value = ($requester != null && $requester.is_admin == true)
    }

    precondition ($league.owner_id == $auth.id || $my_membership != null || $is_site_admin) {
      error_type = "accessdenied"
      error = "You don't have access to this league."
    }

    db.get user {
      field_name = "id"
      field_value = $league.owner_id
      output = ["id", "username", "display_name", "avatar_url"]
    } as $owner

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && ($db.league_membership.status == "active" || $db.league_membership.status == "invited")
      sort = {league_membership.joined_at: "asc"}
      return = {type: "list", paging: {page: 1, per_page: 100}}
    } as $members_page

    var $member_rows {
      value = []
    }

    foreach ($members_page.items) {
      each as $m {
        db.get user {
          field_name = "id"
          field_value = $m.user_id
          output = ["id", "username", "display_name", "avatar_url"]
        } as $member_user

        array.push $member_rows {
          value = {
            membership_id: $m.id
            user     : $member_user
            role     : $m.role
            status   : $m.status
            joined_at: $m.joined_at
            wins     : $m.wins
            losses   : $m.losses
          }
        }
      }
    }
  }

  response = {league: $league, owner: $owner, my_membership: $my_membership, members: $member_rows}
  guid = "bp3g9Y05O1tU0H7h_lXnEuI2sFw"
}

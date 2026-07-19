// Remove a member from a group (owner/admin only). The group owner themself
// cannot be removed. Sets membership status to removed and decrements
// member_count.
query "groups/{id}/members/{userId}" verb=DELETE {
  api_group = "brackets"
  auth = "user"

  input {
    // Group id
    int id
  
    // User id to remove
    int userId
  }

  stack {
    precondition ($auth[""] != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.get fantasy_group {
      field_name = "id"
      field_value = $input.id
    } as $group
  
    precondition ($group != null) {
      error_type = "notfound"
      error = "Group not found."
    }
  
    db.query group_membership {
      where = $db.group_membership.group_id == $group.id && $db.group_membership.user_id == $auth.id
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
  
    var $is_group_admin {
      value = ($my_membership != null && $my_membership.status == "active" && ($my_membership.role == "owner" || $my_membership.role == "admin"))
    }
  
    precondition ($group.owner_id == $auth.id || $is_group_admin || $is_site_admin) {
      error_type = "accessdenied"
      error = "Only the group owner or an admin can remove members."
    }
  
    precondition ($input.userId != $group.owner_id) {
      error_type = "inputerror"
      error = "The group owner cannot be removed."
    }
  
    db.query group_membership {
      where = $db.group_membership.group_id == $group.id && $db.group_membership.user_id == $input.userId
      return = {type: "single"}
    } as $target
  
    precondition ($target != null && $target.status == "active") {
      error_type = "notfound"
      error = "Member not found."
    }
  
    db.edit group_membership {
      field_name = "id"
      field_value = $target.id
      data = {status: "removed"}
    } as $removed
  
    db.edit fantasy_group {
      field_name = "id"
      field_value = $group.id
      data = {member_count: ($group.member_count - 1)}
    } as $group_updated
  }

  response = {ok: true, membership: $removed}
}
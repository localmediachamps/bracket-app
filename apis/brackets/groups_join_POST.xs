// Join a group by invite code. The code is the secret for all privacy levels.
// Removed members are reactivated; member_limit is enforced; the owner is
// notified (group_member_joined).
query "groups/join" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // 8-char group invite code
    text invite_code filters=trim|upper
  }

  stack {
    precondition ($auth[""] != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.query fantasy_group {
      where = $db.fantasy_group.invite_code == $input.invite_code
      return = {type: "single"}
    } as $group
  
    precondition ($group != null) {
      error_type = "notfound"
      error = "Group not found."
    }
  
    db.query group_membership {
      where = $db.group_membership.group_id == $group.id && $db.group_membership.user_id == $auth.id
      return = {type: "single"}
    } as $membership
  
    precondition ($membership == null || $membership.status != "active") {
      error_type = "inputerror"
      error = "You are already a member of this group."
    }
  
    var $result_membership {
      value = null
    }
  
    conditional {
      if ($membership != null) {
        // Rejoin after a previous removal
        db.edit group_membership {
          field_name = "id"
          field_value = $membership.id
          data = {status: "active", role: "member", joined_at: now}
        } as $reactivated
      
        var.update $result_membership {
          value = $reactivated
        }
      }
    
      else {
        precondition ($group.member_limit == null || $group.member_count < $group.member_limit) {
          error_type = "inputerror"
          error = "This group is full."
        }
      
        db.add group_membership {
          data = {
            created_at: now
            group_id  : $group.id
            user_id   : $auth.id
            role      : "member"
            status    : "active"
            joined_at : now
          }
        } as $new_membership
      
        var.update $result_membership {
          value = $new_membership
        }
      }
    }
  
    db.edit fantasy_group {
      field_name = "id"
      field_value = $group.id
      data = {member_count: ($group.member_count + 1)}
    } as $group_updated
  
    // Notify the group owner (not when the owner rejoins their own group)
    conditional {
      if ($group.owner_id != $auth.id) {
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
            user_id: $group.owner_id
            type   : "group_member_joined"
            title  : $joiner_name ~ " joined " ~ $group.name
            data   : {group_id: $group.id, tournament_id: $group.tournament_id}
          }
        } as $notify_result
      }
    }
  }

  response = {group: $group_updated, membership: $result_membership}
}
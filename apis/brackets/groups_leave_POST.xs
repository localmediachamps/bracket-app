// Leave a group. An owner leaving with other members transfers ownership to the
// earliest-joined remaining member; the last member leaving deletes the group
// (and all of its memberships).
query "groups/{id}/leave" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // Group id
    int id
  }

  stack {
    precondition ($auth.id != null) {
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
    } as $membership
  
    precondition ($membership != null && $membership.status == "active") {
      error_type = "inputerror"
      error = "You are not an active member of this group."
    }
  
    // Other active members (potential heirs)
    db.query group_membership {
      where = $db.group_membership.group_id == $group.id && $db.group_membership.status == "active" && $db.group_membership.user_id != $auth.id
      sort = {group_membership.joined_at: "asc"}
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
        // Last member leaving: remove all memberships then the group
        db.query group_membership {
          where = $db.group_membership.group_id == $group.id
          return = {type: "list"}
        } as $all_memberships
      
        foreach ($all_memberships) {
          each as $gm {
            db.del group_membership {
              field_name = "id"
              field_value = $gm.id
            }
          }
        }
      
        db.del fantasy_group {
          field_name = "id"
          field_value = $group.id
        }
      
        var.update $deleted {
          value = true
        }
      }
    
      elseif ($membership.role == "owner") {
        // Transfer ownership to the earliest-joined remaining member
        var $heir {
          value = $others|first
        }
      
        db.edit group_membership {
          field_name = "id"
          field_value = $heir.id
          data = {role: "owner"}
        } as $heir_updated
      
        db.edit group_membership {
          field_name = "id"
          field_value = $membership.id
          data = {status: "removed"}
        } as $departed
      
        db.edit fantasy_group {
          field_name = "id"
          field_value = $group.id
          data = {
            owner_id    : $heir.user_id
            member_count: ($group.member_count - 1)
          }
        } as $group_updated
      
        var.update $new_owner_id {
          value = $heir.user_id
        }
      }
    
      else {
        db.edit group_membership {
          field_name = "id"
          field_value = $membership.id
          data = {status: "removed"}
        } as $departed_member
      
        db.edit fantasy_group {
          field_name = "id"
          field_value = $group.id
          data = {member_count: ($group.member_count - 1)}
        } as $group_updated_member
      }
    }
  }

  response = {
    ok          : true
    deleted     : $deleted
    new_owner_id: $new_owner_id
  }
}
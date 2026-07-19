// Update group settings. Allowed for the group owner, an active admin-role
// member, or a site admin.
query "groups/{id}" verb=PATCH {
  api_group = "brackets"
  auth = "user"

  input {
    // Group id
    int id
  
    // New name
    text? name? filters=trim|min:1
  
    // New description
    text? description? filters=trim
  
    // public | unlisted | private
    text? privacy? filters=trim|lower
  
    // New member cap
    int? member_limit? filters=min:2
  
    // New group emoji
    text? avatar_emoji? filters=trim
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
  
    conditional {
      if ($input.privacy != null) {
        precondition ($input.privacy == "public" || $input.privacy == "unlisted" || $input.privacy == "private") {
          error_type = "inputerror"
          error = "privacy must be public, unlisted, or private."
        }
      }
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
      error = "Only the group owner or an admin can update this group."
    }
  
    var $payload {
      value = {}
    }
  
    conditional {
      if ($input.name != null) {
        var.update $payload {
          value = $payload|set:"name":$input.name
        }
      }
    }
  
    conditional {
      if ($input.description != null) {
        var.update $payload {
          value = $payload
            |set:"description":$input.description
        }
      }
    }
  
    conditional {
      if ($input.privacy != null) {
        var.update $payload {
          value = $payload|set:"privacy":$input.privacy
        }
      }
    }
  
    conditional {
      if ($input.member_limit != null) {
        var.update $payload {
          value = $payload
            |set:"member_limit":$input.member_limit
        }
      }
    }
  
    conditional {
      if ($input.avatar_emoji != null) {
        var.update $payload {
          value = $payload
            |set:"avatar_emoji":$input.avatar_emoji
        }
      }
    }
  
    db.patch fantasy_group {
      field_name = "id"
      field_value = $group.id
      data = $payload
    } as $updated_group
  }

  response = $updated_group
}
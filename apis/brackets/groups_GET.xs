// Group detail: basic info is always public; the members preview (first 10 active
// members) requires public privacy, membership, ownership, or admin.
query "groups/{id}" verb=GET {
  api_group = "brackets"

  input {
    // Group id
    int id
  }

  stack {
    db.get fantasy_group {
      field_name = "id"
      field_value = $input.id
    } as $group
  
    precondition ($group != null) {
      error_type = "notfound"
      error = "Group not found."
    }
  
    db.get user {
      field_name = "id"
      field_value = $group.owner_id
      output = ["id", "username", "display_name", "avatar_url"]
    } as $owner
  
    // Decide whether the requester may see the members list
    var $can_view_members {
      value = $group.privacy == "public"
    }
  
    conditional {
      if ($can_view_members == false && $auth[""] != null && $auth.id != null) {
        conditional {
          if ($group.owner_id == $auth.id) {
            var.update $can_view_members {
              value = true
            }
          }
        }
      
        conditional {
          if ($can_view_members == false) {
            db.query group_membership {
              where = $db.group_membership.group_id == $group.id && $db.group_membership.user_id == $auth.id && $db.group_membership.status == "active"
              return = {type: "exists"}
            } as $is_member
          
            conditional {
              if ($is_member) {
                var.update $can_view_members {
                  value = true
                }
              }
            }
          }
        }
      
        conditional {
          if ($can_view_members == false) {
            db.get user {
              field_name = "id"
              field_value = $auth.id
              output = ["id", "is_admin"]
            } as $admin_check
          
            conditional {
              if ($admin_check != null && $admin_check.is_admin) {
                var.update $can_view_members {
                  value = true
                }
              }
            }
          }
        }
      }
    }
  
    var $members {
      value = null
    }
  
    conditional {
      if ($can_view_members) {
        db.query group_membership {
          where = $db.group_membership.group_id == $group.id && $db.group_membership.status == "active"
          sort = {group_membership.joined_at: "asc"}
          return = {type: "list", paging: {page: 1, per_page: 10}}
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
                user     : $member_user
                role     : $m.role
                joined_at: $m.joined_at
              }
            }
          }
        }
      
        var.update $members {
          value = $member_rows
        }
      }
    }
  }

  response = {group: $group, owner: $owner, members: $members}
}
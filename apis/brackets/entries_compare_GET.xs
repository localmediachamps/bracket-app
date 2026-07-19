// Head-to-head comparison of two entries. Allowed when the requester owns either
// entry, shares any group with an entry owner, or is an admin.
query "entries/{id}/compare/{otherId}" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    // First entry id
    int id
  
    // Second entry id
    int otherId
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.get user_bracket {
      field_name = "id"
      field_value = $input.id
    } as $entry_a
  
    precondition ($entry_a != null) {
      error_type = "notfound"
      error = "Entry not found."
    }
  
    db.get user_bracket {
      field_name = "id"
      field_value = $input.otherId
    } as $entry_b
  
    precondition ($entry_b != null) {
      error_type = "notfound"
      error = "Other entry not found."
    }
  
    var $allowed {
      value = ($entry_a.user_id == $auth.id || $entry_b.user_id == $auth.id)
    }
  
    // Admin override
    conditional {
      if ($allowed == false) {
        db.get user {
          field_name = "id"
          field_value = $auth.id
          output = ["id", "is_admin"]
        } as $admin_check
      
        conditional {
          if ($admin_check != null && $admin_check.is_admin) {
            var.update $allowed {
              value = true
            }
          }
        }
      }
    }
  
    // Shared-group access: any active group shared with either entry owner
    conditional {
      if ($allowed == false) {
        db.query group_membership {
          where = $db.group_membership.user_id == $auth.id && $db.group_membership.status == "active"
          return = {type: "list"}
        } as $my_memberships
      
        var $my_group_ids {
          value = $my_memberships|map:$$.group_id
        }
      
        foreach ([$entry_a.user_id, $entry_b.user_id]) {
          each as $owner_id {
            conditional {
              if ($allowed == false && $owner_id != $auth.id) {
                db.query group_membership {
                  where = $db.group_membership.user_id == $owner_id && $db.group_membership.status == "active"
                  return = {type: "list"}
                } as $their_memberships
              
                var $their_group_ids {
                  value = $their_memberships|map:$$.group_id
                }
              
                var $shared_groups {
                  value = $my_group_ids|intersect:$their_group_ids
                }
              
                conditional {
                  if (($shared_groups|count) > 0) {
                    var.update $allowed {
                      value = true
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  
    precondition ($allowed) {
      error_type = "accessdenied"
      error = "You do not have access to compare these entries."
    }
  
    function.run head_to_head {
      input = {entry_id_a: $input.id, entry_id_b: $input.otherId}
    } as $comparison
  }

  response = $comparison
}
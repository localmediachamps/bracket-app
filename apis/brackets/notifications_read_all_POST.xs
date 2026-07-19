// Mark all of the current user's notifications as read.
query "notifications/read-all" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.query notification {
      where = $db.notification.user_id == $auth.id && $db.notification.read_at == null
      return = {type: "list"}
    } as $unread
  
    var $updated_count {
      value = 0
    }
  
    foreach ($unread) {
      each as $n {
        db.edit notification {
          field_name = "id"
          field_value = $n.id
          data = {read_at: now}
        } as $read_row
      
        math.add $updated_count {
          value = 1
        }
      }
    }
  }

  response = {updated: $updated_count}
}
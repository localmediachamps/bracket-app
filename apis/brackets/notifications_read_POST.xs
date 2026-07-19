// Mark a single notification as read (owner only).
query "notifications/{id}/read" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // Notification id
    int id
  }

  stack {
    precondition ($auth[""] != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.get notification {
      field_name = "id"
      field_value = $input.id
    } as $notification
  
    precondition ($notification != null) {
      error_type = "notfound"
      error = "Notification not found."
    }
  
    precondition ($notification.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "You do not own this notification."
    }
  
    db.edit notification {
      field_name = "id"
      field_value = $notification.id
      data = {read_at: now}
    } as $updated
  }

  response = $updated
}
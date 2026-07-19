// Creates notification rows for one user or fans out to many users.
// Types per ARCHITECTURE.md section 1 (notification table).
// Returns the number of notifications created.
// Create notifications for a single user or many users
function notify {
  input {
    // Recipient user id (single-recipient mode)
    int? user_id?
  
    // Recipient user ids (fan-out mode, takes precedence over user_id)
    int[] user_ids?
  
    // Notification type, e.g. tournament_open, deadline_soon, entry_locked
    text type filters=trim|min:1
  
    // Short headline
    text title filters=trim|min:1
  
    // Longer message body
    text? body?
  
    // Deep-link payload {tournament_id, entry_id, group_id}
    json? data?
  }

  stack {
    // Resolve recipient list: user_ids fan-out wins, else single user_id
    var $targets {
      value = []
    }
  
    conditional {
      if ($input.user_ids != null && ($input.user_ids|count) > 0) {
        var.update $targets {
          value = $input.user_ids
        }
      }
    
      elseif ($input.user_id != null) {
        array.push $targets {
          value = $input.user_id
        }
      }
    }
  
    precondition (($targets|count) > 0) {
      error_type = "inputerror"
      error = "notify requires user_id or a non-empty user_ids array"
    }
  
    var $created {
      value = 0
    }
  
    foreach ($targets) {
      each as $uid {
        db.add notification {
          data = {
            created_at: "now"
            user_id   : $uid
            type      : $input.type
            title     : $input.title
            body      : $input.body
            data      : $input.data
          }
        } as $notification_row
      
        math.add $created {
          value = 1
        }
      }
    }
  }

  response = $created
}
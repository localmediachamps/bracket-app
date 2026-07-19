// Current user's notifications, newest first, paginated, with unread count.
query "me/notifications" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.query notification {
      where = $db.notification.user_id == $auth.id
      sort = {notification.created_at: "desc"}
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $page
  
    db.query notification {
      where = $db.notification.user_id == $auth.id && $db.notification.read_at == null
      return = {type: "count"}
    } as $unread_count
  }

  response = {
    items       : $page.items
    total       : $page.itemsTotal
    page        : $input.page
    per         : $input.per
    unread_count: $unread_count
  }
}
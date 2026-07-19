// Audit log browser (ARCHITECTURE.md section 6: GET /admin/audit-logs).
// Newest first, optionally filtered by entity_type/entity_id, with the actor's
// name joined in. Envelope remapped to {items, total, page, per}.
query "admin/audit-logs" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    // Filter by entity type, e.g. tournament | bracket_match | uploaded_document
    text? entity_type? filters=trim
  
    // Filter by entity id
    int? entity_id?
  
    // Page number (1-based)
    int page?=1 filters=min:1
  
    // Items per page (max 100)
    int per?=25 filters=min:1|max:100
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.query audit_log {
      join = {
        user: {
          table: "user"
          type : "left"
          where: $db.audit_log.actor_id == $db.user.id
        }
      }
    
      where = $db.audit_log.entity_type ==? $input.entity_type && $db.audit_log.entity_id ==? $input.entity_id
      sort = {audit_log.created_at: "desc"}
      eval = {actor_name: $db.user.name}
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $logs
  }

  response = {
    items: $logs.items
    total: $logs.itemsTotal
    page : $logs.curPage
    per  : $logs.perPage
  }
}
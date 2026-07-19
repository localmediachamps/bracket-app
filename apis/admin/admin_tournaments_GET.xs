// Admin list of tournaments across all statuses, newest first (ARCHITECTURE.md section 6).
// Each row carries entry_count (denormalized column) and a computed weight_class_count.
// Envelope is remapped from Xano paging to the contract shape {items, total, page, per}.
query "admin/tournaments" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    // Page number (1-based)
    int page?=1 filters=min:1
  
    // Items per page (max 100)
    int per?=25 filters=min:1|max:100
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.query tournament {
      sort = {tournament.created_at: "desc"}
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $page_result
  
    // Weight classes are few (about 10 per tournament) — one bounded scan,
    // counted in memory per tournament to avoid N count queries.
    db.query weight_class {
      return = {type: "list"}
      output = ["id", "tournament_id"]
    } as $all_weight_classes
  
    var $items {
      value = []
    }
  
    foreach ($page_result.items) {
      each as $t {
        var $wc_count {
          value = $all_weight_classes|filter:($$.tournament_id == $t.id)|count
        }
      
        var $entry_count {
          value = $t.entry_count|first_notnull:0
        }
      
        var $row {
          value = $t
            |set:"weight_class_count":$wc_count
            |set:"entry_count":$entry_count
        }
      
        array.push $items {
          value = $row
        }
      }
    }
  }

  response = {
    items: $items
    total: $page_result.itemsTotal
    page : $page_result.curPage
    per  : $page_result.perPage
  }
}
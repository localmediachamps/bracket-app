// List tournament cards with computed weight class and competitor counts.
// Non-admins never see draft/importing/needs_review/cancelled (or archived — hidden
// from the directory per ARCHITECTURE.md section 4). q matches name case-insensitively.
query tournaments verb=GET {
  api_group = "brackets"

  input {
    // Filter by exact status (restricted statuses are admin-only)
    text? status? filters=trim|lower
  
    // Case-insensitive name search
    text? q? filters=trim
  
    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    // Public statuses only. Admins use GET /admin/tournaments for the full list —
    // reading the user table's is_admin field from a public endpoint is denied
    // by Xano (ACCESS_DENIED), so no admin branch lives here.
    conditional {
      if ($input.q != null && $input.q != "") {
        db.query tournament {
          where = $db.tournament.status != "draft" && $db.tournament.status != "importing" && $db.tournament.status != "needs_review" && $db.tournament.status != "cancelled" && $db.tournament.status != "archived" && $db.tournament.status ==? $input.status && $db.tournament.name includes? $input.q
          sort = {tournament.year: "desc"}
          return = {
            type  : "list"
            paging: {page: $input.page, per_page: $input.per, totals: true}
          }
        } as $page
      }
    
      else {
        db.query tournament {
          where = $db.tournament.status != "draft" && $db.tournament.status != "importing" && $db.tournament.status != "needs_review" && $db.tournament.status != "cancelled" && $db.tournament.status != "archived" && $db.tournament.status ==? $input.status
          sort = {tournament.year: "desc"}
          return = {
            type  : "list"
            paging: {page: $input.page, per_page: $input.per, totals: true}
          }
        } as $page
      }
    }
  
    // Enrich each card with computed counts
    var $items {
      value = []
    }
  
    foreach ($page.items) {
      each as $t {
        db.query weight_class {
          where = $db.weight_class.tournament_id == $t.id
          return = {type: "list"}
        } as $classes
      
        var $competitor_count {
          value = 0
        }
      
        foreach ($classes) {
          each as $wc {
            math.add $competitor_count {
              value = $wc.competitor_count
            }
          }
        }
      
        var $wc_count {
          value = $classes|count
        }
      
        array.push $items {
          value = {
            id                : $t.id
            name              : $t.name
            slug              : $t.slug
            year              : $t.year
            status            : $t.status
            location          : $t.location
            start_date        : $t.start_date
            end_date          : $t.end_date
            locks_at          : $t.locks_at
            weight_class_count: $wc_count
            competitor_count  : $competitor_count
            entry_count       : $t.entry_count
            game_modes        : $t.game_modes
          }
        }
      }
    }
  }

  response = {
    items: $items
    total: $page.itemsTotal
    page : $input.page
    per  : $input.per
  }
}
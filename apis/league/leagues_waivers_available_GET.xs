// The undrafted pool for this league: every canonical_wrestler NOT currently
// on an active roster_slot in this league. No schedule pipeline exists yet
// (Phase 2), so this can't filter to "competing this week" - it's the full
// undrafted pool, paginated by id.
query "leagues/waivers/available" verb=GET {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int? page?=1 filters=min:1
    int? per_page?=50 filters=min:1|max:200
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get league {
      field_name = "id"
      field_value = $input.league_id
    } as $league

    precondition ($league != null) {
      error_type = "notfound"
      error = "League not found."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id
      return = {type: "single"}
    } as $my_membership

    precondition ($my_membership != null && $my_membership.status == "active") {
      error_type = "accessdenied"
      error = "You are not an active member of this league."
    }

    db.query roster_slot {
      where = $db.roster_slot.league_id == $league.id && $db.roster_slot.status == "active"
      return = {type: "list"}
    } as $rostered

    var $rostered_map {
      value = {}
    }

    foreach ($rostered) {
      each as $r {
        var.update $rostered_map {
          value = $rostered_map|set:($r.canonical_wrestler_id|to_text):true
        }
      }
    }

    db.query canonical_wrestler {
      sort = {canonical_wrestler.id: "asc"}
      return = {type: "list", paging: {page: $input.page, per_page: $input.per_page}}
    } as $candidate_page

    var $available_rows {
      value = []
    }

    foreach ($candidate_page.items) {
      each as $candidate {
        conditional {
          if (($rostered_map|has:($candidate.id|to_text)) == false) {
            array.push $available_rows {
              value = $candidate
            }
          }
        }
      }
    }
  }

  response = {
    wrestlers: $available_rows
    page     : $candidate_page.curPage
    per_page : $input.per_page
  }
  guid = "HvnT8kw6wN5JfTnuM4lWu-YxHng"
}

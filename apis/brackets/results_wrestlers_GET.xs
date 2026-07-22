// Wrestler Library - search/browse every canonical_wrestler, filterable by
// school and current weight class. A third pathway into wrestler profiles
// alongside clicking through Results or Teams. Public, same as the rest of
// the results explorer. current_weight_class is denormalized (see
// tables/canonical_wrestler.xs) from each wrestler's most recent
// wrestler_match_history row, refreshed via admin/wrestlers/refresh-weights.
query "results/wrestlers" verb=GET {
  api_group = "brackets"

  input {
    text? q? filters=trim|max:100
    int? team_id?
    text? weight_class?
    text? sort?=name

    int page?=1 filters=min:1
    int per?=24 filters=min:1|max:100
  }

  stack {
    var $q_lower {
      value = $input.q|to_lower
    }

    var $page {
      value = null
    }

    conditional {
      if ($input.sort == "weight") {
        db.query canonical_wrestler {
          where = ($input.q == null || (($db.canonical_wrestler.display_name|to_lower) includes $q_lower)) && ($db.canonical_wrestler.current_team_id ==? $input.team_id) && ($db.canonical_wrestler.current_weight_class ==? $input.weight_class)
          sort = {canonical_wrestler.current_weight_class: "asc"}
          return = {
            type  : "list"
            paging: {page: $input.page, per_page: $input.per, totals: true}
          }
        } as $page_weight

        var.update $page {
          value = $page_weight
        }
      }
      else {
        db.query canonical_wrestler {
          where = ($input.q == null || (($db.canonical_wrestler.display_name|to_lower) includes $q_lower)) && ($db.canonical_wrestler.current_team_id ==? $input.team_id) && ($db.canonical_wrestler.current_weight_class ==? $input.weight_class)
          sort = {canonical_wrestler.legal_last_name: "asc", canonical_wrestler.legal_first_name: "asc"}
          return = {
            type  : "list"
            paging: {page: $input.page, per_page: $input.per, totals: true}
          }
        } as $page_name

        var.update $page {
          value = $page_name
        }
      }
    }

    // Small, cheap table (79 rows) - fetch all rather than filtering by a
    // dynamic id list, mirroring results/wrestlers/{id}'s own team-name join.
    db.query canonical_team {
      return = {type: "list"}
    } as $teams

    var $team_map {
      value = {}
    }

    foreach ($teams) {
      each as $t {
        var.update $team_map {
          value = $team_map|set:$t.id:{id: $t.id, name: $t.name, logo_url: $t.logo_url}
        }
      }
    }

    var $out {
      value = []
    }

    foreach ($page.items) {
      each as $w {
        var $team {
          value = null
        }

        conditional {
          if ($w.current_team_id != null && ($team_map|has:$w.current_team_id)) {
            var.update $team {
              value = $team_map[$w.current_team_id]
            }
          }
        }

        array.push $out {
          value = {
            id                 : $w.id
            display_name       : $w.display_name
            current_team       : $team
            current_weight_class: $w.current_weight_class
            profile_url        : $w.profile_url
          }
        }
      }
    }
  }

  response = {
    items: $out
    total: $page.itemsTotal
    page : $input.page
    per  : $input.per
  }
  guid = "T4vNq8XjLp2WkZbHo5EsRc6yMd3F"
}

// The undrafted pool for this league: every canonical_wrestler NOT currently
// on an active roster_slot in this league, optionally narrowed by weight
// class / team, sortable by name. No schedule pipeline exists yet (Phase 2),
// so this can't filter to "competing this week" - it's the full undrafted
// pool.
//
// Filters rostered wrestlers out BEFORE paging, not after - the previous
// version queried canonical_wrestler paged by id, then dropped rostered
// rows from that page in-memory, so early pages (and any league whose
// drafted wrestlers happen to occupy low ids, as demo/seed data does) could
// come back looking completely empty even though thousands of undrafted
// wrestlers exist further in the table.
query "leagues/waivers/available" verb=GET {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int? page?=1 filters=min:1
    int? per_page?=50 filters=min:1|max:200
    int? weight_class?
    int? team_id?
    text? q? filters=trim|max:100

    // Defaults to true - most teams only ever start one wrestler per weight,
    // so showing every backup/redshirt on every roster by default buried the
    // wrestlers actually worth claiming under hundreds of irrelevant ones.
    // Pass false to see the full undrafted pool (bench guys, injury fill-ins,
    // etc.) via an explicit "show all wrestlers" toggle.
    bool? starters_only?=true

    // weight (ascending) | name (a-z) | school (a-z, then weight)
    text? sort_by?=weight filters=trim|lower
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

    // Only wrestlers who actually rostered for THIS league's own season -
    // a league scoped to an older season can't surface a future signee or
    // someone who'd already graduated by then as "available."
    db.get season {
      field_name = "id"
      field_value = $league.season_id
    } as $waivers_season

    function.run season_label_from_year {
      input = {year: $waivers_season.year}
    } as $waivers_season_label

    db.query canonical_wrestler_team {
      where = $db.canonical_wrestler_team.season_label == $waivers_season_label
      return = {type: "list", paging: {page: 1, per_page: 50000}}
    } as $season_roster_rows

    var $season_roster_map {
      value = {}
    }

    // is_starter is a stored field (see canonical_wrestler_team.xs), kept
    // fresh by tasks/compute_starter_tags.xs - reading it here is a plain
    // map lookup, not a live per-team recomputation, so this stays cheap
    // even across the hundreds of teams a league-wide waiver pool spans.
    var $starter_map {
      value = {}
    }

    foreach ($season_roster_rows.items) {
      each as $sr {
        var $sr_key {
          value = ($sr.canonical_wrestler_id|to_text)
        }

        var.update $season_roster_map {
          value = $season_roster_map|set:$sr_key:true
        }

        var.update $starter_map {
          value = $starter_map|set:$sr_key:($sr.is_starter == true)
        }
      }
    }

    db.query canonical_team {
      return = {type: "list", paging: {page: 1, per_page: 50000}}
    } as $all_teams

    var $team_name_map {
      value = {}
    }

    foreach ($all_teams.items) {
      each as $tm {
        var.update $team_name_map {
          value = $team_name_map|set:($tm.id|to_text):$tm.name
        }
      }
    }

    var $weight_text {
      value = null
    }

    conditional {
      if ($input.weight_class != null) {
        var.update $weight_text {
          value = ($input.weight_class|to_text)
        }
      }
    }

    var $q_lower {
      value = $input.q|to_lower
    }

    // Fetch every matching candidate in one call (canonical_wrestler tops
    // out around ~5,400 rows - well under the ~50k-per-call ceiling this
    // app has already confirmed works reliably), filter out rostered
    // wrestlers, THEN paginate the filtered result manually - the opposite
    // order from before.
    db.query canonical_wrestler {
      where = ($input.weight_class == null || $db.canonical_wrestler.current_weight_class == $weight_text) && ($input.team_id == null || $db.canonical_wrestler.current_team_id == $input.team_id) && ($input.q == null || (($db.canonical_wrestler.display_name|to_lower) includes $q_lower))
      sort = {canonical_wrestler.display_name: "asc"}
      return = {type: "list", paging: {page: 1, per_page: 50000}}
    } as $all_candidates

    var $available_all {
      value = []
    }

    foreach ($all_candidates.items) {
      each as $candidate {
        var $candidate_key {
          value = ($candidate.id|to_text)
        }

        var $passes_starter_filter {
          value = true
        }

        conditional {
          if ($input.starters_only == true) {
            var.update $passes_starter_filter {
              value = ($starter_map|get:$candidate_key:false)
            }
          }
        }

        conditional {
          if (($rostered_map|has:$candidate_key) == false && ($season_roster_map|has:$candidate_key) && $passes_starter_filter) {
            array.push $available_all {
              value = $candidate
            }
          }
        }
      }
    }

    // Default DB sort above (display_name asc) already covers sort_by=name -
    // only weight and school need a re-sort here.
    var $sorted_all {
      value = $available_all
    }

    conditional {
      if ($input.sort_by == "weight") {
        var.update $sorted_all {
          value = $available_all|sort:"current_weight_class":"text"
        }
      }
      elseif ($input.sort_by == "school") {
        // Sort by the secondary key (weight) FIRST, then the primary key
        // (school) - |sort is stable, so weight order survives within each
        // school group only if it's already in place before the school sort
        // runs, not after.
        var $weight_first {
          value = $available_all|sort:"current_weight_class":"text"
        }

        var $with_team_name {
          value = []
        }

        foreach ($weight_first) {
          each as $ca {
            var $ca_team_name {
              value = $team_name_map|get:($ca.current_team_id|to_text):""
            }

            array.push $with_team_name {
              value = ($ca|set:"_sort_team_name":$ca_team_name)
            }
          }
        }

        var.update $sorted_all {
          value = $with_team_name|sort:"_sort_team_name":"text"
        }
      }
    }

    var $total_count {
      value = ($sorted_all|count)
    }

    var $offset {
      value = (($input.page - 1) * $input.per_page)
    }

    var $available_page {
      value = ($sorted_all|slice:$offset:$input.per_page)
    }

    // Enrich just this page (not the whole undrafted pool) with the same
    // record + notable-wins-vs-ranked card the rankings pages show, so a
    // manager can actually research a claim instead of picking blind.
    var $enriched_page {
      value = []
    }

    foreach ($available_page) {
      each as $candidate {
        function.run build_wrestler_competition_card {
          input = {canonical_wrestler_id: $candidate.id, season_year: $waivers_season.year}
        } as $card

        array.push $enriched_page {
          value = $card
        }
      }
    }
  }

  response = {
    wrestlers  : $enriched_page
    page       : $input.page
    per_page   : $input.per_page
    total_count: $total_count
  }
  guid = "HvnT8kw6wN5JfTnuM4lWu-YxHng"
}

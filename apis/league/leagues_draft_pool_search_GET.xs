// Searchable draft-pool browser. Same endpoint serves both draft contexts:
//   - Preseason draft (season_week_id omitted): the full undrafted D1
//     canonical_wrestler pool, name-searchable.
//   - Tournament mini-draft (season_week_id set): restricted to that week's
//     linked tournament's actual field (its `wrestler` rows), with each
//     entry's real weight included - entries with no canonical_wrestler
//     link yet are excluded (can't be scored - see dependency B).
// Exclusion of already-picked wrestlers is scoped to this specific draft_id.
query "leagues/draft/pool" verb=GET {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int? season_week_id?
    text? q? filters=trim
    int? page?=1 filters=min:1
    int? per_page?=30 filters=min:1|max:100
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $input.league_id && $db.league_membership.user_id == $auth.id && $db.league_membership.status == "active"
      return = {type: "exists"}
    } as $is_member

    precondition ($is_member) {
      error_type = "accessdenied"
      error = "You are not an active member of this league."
    }

    db.query draft {
      where = $db.draft.league_id == $input.league_id && (($input.season_week_id == null && $db.draft.season_week_id == null) || $db.draft.season_week_id == $input.season_week_id)
      return = {type: "single"}
    } as $draft

    precondition ($draft != null) {
      error_type = "notfound"
      error = "This draft doesn't exist yet."
    }

    db.query draft_pick {
      where = $db.draft_pick.draft_id == $draft.id
      return = {type: "list"}
    } as $existing_picks

    var $drafted_map {
      value = {}
    }

    foreach ($existing_picks) {
      each as $p {
        var.update $drafted_map {
          value = $drafted_map|set:($p.canonical_wrestler_id|to_text):true
        }
      }
    }

    var $wrestlers {
      value = []
    }

    var $cur_page {
      value = $input.page
    }

    conditional {
      if ($draft.season_week_id != null) {
        db.get season_week {
          field_name = "id"
          field_value = $draft.season_week_id
        } as $week

        var $q_lower {
          value = $input.q|to_lower
        }

        db.query wrestler {
          where = $db.wrestler.tournament_id == $week.linked_tournament_id && $db.wrestler.canonical_wrestler_id != null && (($input.q == null) || (($db.wrestler.name|to_lower) includes $q_lower))
          sort = {wrestler.name: "asc"}
          return = {type: "list", paging: {page: $input.page, per_page: $input.per_page}}
        } as $entry_page

        foreach ($entry_page.items) {
          each as $entry {
            conditional {
              if (($drafted_map|has:($entry.canonical_wrestler_id|to_text)) == false) {
                db.get weight_class {
                  field_name = "id"
                  field_value = $entry.weight_class_id
                  output = ["id", "weight"]
                } as $wc

                array.push $wrestlers {
                  value = {
                    id    : $entry.canonical_wrestler_id
                    name  : $entry.name
                    team  : {name: $entry.school}
                    weight: $wc.weight
                  }
                }
              }
            }
          }
        }

        var.update $cur_page {
          value = $entry_page.curPage
        }
      }

      else {
        var $q_lower2 {
          value = $input.q|to_lower
        }

        db.query canonical_wrestler {
          where = ($input.q == null) || (($db.canonical_wrestler.display_name|to_lower) includes $q_lower2)
          sort = {canonical_wrestler.display_name: "asc"}
          return = {type: "list", paging: {page: $input.page, per_page: $input.per_page}}
        } as $candidate_page

        foreach ($candidate_page.items) {
          each as $candidate {
            conditional {
              if (($drafted_map|has:($candidate.id|to_text)) == false) {
                db.get canonical_team {
                  field_name = "id"
                  field_value = $candidate.current_team_id
                  output = ["id", "name"]
                } as $team

                array.push $wrestlers {
                  value = {
                    id    : $candidate.id
                    name  : $candidate.display_name
                    team  : $team
                    weight: null
                  }
                }
              }
            }
          }
        }

        var.update $cur_page {
          value = $candidate_page.curPage
        }
      }
    }
  }

  response = {
    wrestlers: $wrestlers
    page     : $cur_page
  }
  guid = "SGd7Lq5UOEt1HkVolfeRDV36jhc"
}

// Full tournament export — historical archive snapshot (ARCHITECTURE.md sections 6
// and 11: GET /admin/tournaments/{id}/export).
// Single JSON document: tournament, weight classes, competitors, matches (with result
// history), entries (with picks), pick'em entries (with picks), groups (with
// memberships), scoring config, exported_at. All queries are filtered by tournament
// (memberships per group, bounded by that tournament's group count).
query "admin/tournaments/{id}/export" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    db.query weight_class {
      where = $db.weight_class.tournament_id == $input.id
      sort = {weight_class.display_order: "asc"}
      return = {type: "list"}
    } as $weight_classes
  
    db.query wrestler {
      where = $db.wrestler.tournament_id == $input.id
      sort = {wrestler.id: "asc"}
      return = {type: "list"}
    } as $competitors
  
    db.query bracket_match {
      where = $db.bracket_match.tournament_id == $input.id
      sort = {bracket_match.id: "asc"}
      return = {type: "list"}
    } as $matches
  
    db.query match_result_history {
      where = $db.match_result_history.tournament_id == $input.id
      sort = {match_result_history.id: "asc"}
      return = {type: "list"}
    } as $result_history
  
    db.query user_bracket {
      where = $db.user_bracket.tournament_id == $input.id
      sort = {user_bracket.id: "asc"}
      return = {type: "list"}
    } as $entries
  
    db.query user_pick {
      where = $db.user_pick.tournament_id == $input.id
      sort = {user_pick.id: "asc"}
      return = {type: "list"}
    } as $picks
  
    db.query pickem_entry {
      where = $db.pickem_entry.tournament_id == $input.id
      sort = {pickem_entry.id: "asc"}
      return = {type: "list"}
    } as $pickem_entries
  
    db.query pickem_pick {
      where = $db.pickem_pick.tournament_id == $input.id
      sort = {pickem_pick.id: "asc"}
      return = {type: "list"}
    } as $pickem_picks
  
    db.query fantasy_group {
      where = $db.fantasy_group.tournament_id == $input.id
      sort = {fantasy_group.id: "asc"}
      return = {type: "list"}
    } as $groups
  
    // Nest result history under each match
    var $matches_out {
      value = []
    }
  
    foreach ($matches) {
      each as $m {
        var $m_history {
          value = $result_history|filter:($$.bracket_match_id == $m.id)
        }
      
        array.push $matches_out {
          value = $m|set:"result_history":$m_history
        }
      }
    }
  
    // Nest picks under each bracket entry
    var $entries_out {
      value = []
    }
  
    foreach ($entries) {
      each as $e {
        var $e_picks {
          value = $picks|filter:($$.user_bracket_id == $e.id)
        }
      
        array.push $entries_out {
          value = $e|set:"picks":$e_picks
        }
      }
    }
  
    // Nest picks under each pick'em entry
    var $pickem_out {
      value = []
    }
  
    foreach ($pickem_entries) {
      each as $pe {
        var $pe_picks {
          value = $pickem_picks|filter:($$.pickem_entry_id == $pe.id)
        }
      
        array.push $pickem_out {
          value = $pe|set:"picks":$pe_picks
        }
      }
    }
  
    // Nest memberships under each group (one filtered query per group)
    var $groups_out {
      value = []
    }
  
    foreach ($groups) {
      each as $g {
        db.query group_membership {
          where = $db.group_membership.group_id == $g.id
          return = {type: "list"}
        } as $g_members
      
        array.push $groups_out {
          value = $g|set:"memberships":$g_members
        }
      }
    }
  
    var $exported_at {
      value = now
    }
  }

  response = {
    tournament    : $tournament
    weight_classes: $weight_classes
    competitors   : $competitors
    matches       : $matches_out
    entries       : $entries_out
    pickem_entries: $pickem_out
    groups        : $groups_out
    scoring_config: $tournament.scoring_config
    exported_at   : $exported_at
  }
}
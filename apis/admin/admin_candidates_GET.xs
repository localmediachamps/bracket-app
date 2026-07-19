// Lists external_result_candidate rows for a tournament, newest first
// (GET /admin/tournaments/{id}/candidates?status=&page=&per=). Each row is
// enriched with its source name and, when matched_match_id is set, a brief of
// the matched bracket_match {id, round_code, round_label, match_number,
// weight, status, top_participant, bottom_participant}.
// List ingestion candidates for a tournament with source and match briefs
query "admin/tournaments/{tournament_id}/candidates" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int tournament_id
  
    // Optional status filter: detected | parsed | normalized | matched |
    // needs_review | approved | auto_approved | rejected | conflict | failed
    text? status? filters=trim|lower
  
    // Page number (1-based)
    int page?=1 filters=min:1
  
    // Items per page (max 100)
    int per?=25 filters=min:1|max:100
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get tournament {
      field_name = "id"
      field_value = $input.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    db.query external_result_candidate {
      where = $db.external_result_candidate.tournament_id == $input.tournament_id && $db.external_result_candidate.status ==? $input.status
      sort = {external_result_candidate.created_at: "desc"}
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $page_result
  
    // Source id -> name map (deleted sources simply yield a null name)
    db.query results_source_config {
      where = $db.results_source_config.tournament_id == $input.tournament_id
      return = {type: "list"}
      output = ["id", "name"]
    } as $sources
  
    var $source_map {
      value = {}
    }
  
    foreach ($sources) {
      each as $src {
        var.update $source_map {
          value = $source_map|set:$src.id:$src.name
        }
      }
    }
  
    // Collect the matched match ids on this page
    var $matched_ids {
      value = []
    }
  
    foreach ($page_result.items) {
      each as $c {
        conditional {
          if ($c.matched_match_id != null) {
            array.push $matched_ids {
              value = $c.matched_match_id
            }
          }
        }
      }
    }
  
    // Lookup maps for match briefs, loaded only when the page has matches.
    // Tournament-scoped scans filtered in memory: bounded (~600 matches,
    // ~330 wrestlers for NCAA DI) and avoids N per-row queries.
    var $match_map {
      value = {}
    }
  
    var $weight_map {
      value = {}
    }
  
    var $wrestler_map {
      value = {}
    }
  
    conditional {
      if (($matched_ids|count) > 0) {
        db.query bracket_match {
          where = $db.bracket_match.tournament_id == $input.tournament_id
          return = {type: "list"}
          output = [
            "id"
            "round_code"
            "round_label"
            "match_number"
            "weight_class_id"
            "match_status"
            "actual_top_wrestler_id"
            "actual_bottom_wrestler_id"
          ]
        } as $t_matches
      
        foreach ($t_matches) {
          each as $m {
            conditional {
              if ($matched_ids|some:$$ == $m.id) {
                var.update $match_map {
                  value = $match_map|set:$m.id:$m
                }
              }
            }
          }
        }
      
        db.query weight_class {
          where = $db.weight_class.tournament_id == $input.tournament_id
          return = {type: "list"}
          output = ["id", "weight"]
        } as $t_weights
      
        foreach ($t_weights) {
          each as $wc {
            var.update $weight_map {
              value = $weight_map|set:$wc.id:$wc.weight
            }
          }
        }
      
        db.query wrestler {
          where = $db.wrestler.tournament_id == $input.tournament_id
          return = {type: "list"}
          output = ["id", "name"]
        } as $t_wrestlers
      
        foreach ($t_wrestlers) {
          each as $w {
            var.update $wrestler_map {
              value = $wrestler_map|set:$w.id:$w.name
            }
          }
        }
      }
    }
  
    var $items {
      value = []
    }
  
    foreach ($page_result.items) {
      each as $c {
        var $match_brief {
          value = null
        }
      
        conditional {
          if ($c.matched_match_id != null) {
            var $bm {
              value = $match_map[$c.matched_match_id]
            }
          
            conditional {
              if ($bm != null) {
                var $top_name {
                  value = $wrestler_map[$bm.actual_top_wrestler_id]
                }
              
                var $bottom_name {
                  value = $wrestler_map[$bm.actual_bottom_wrestler_id]
                }
              
                var.update $match_brief {
                  value = {
                    id                : $bm.id
                    round_code        : $bm.round_code
                    round_label       : $bm.round_label
                    match_number      : $bm.match_number
                    weight            : $weight_map[$bm.weight_class_id]
                    status            : $bm.match_status
                    top_participant   : $top_name
                    bottom_participant: $bottom_name
                  }
                }
              }
            }
          }
        }
      
        var $row {
          value = $c
            |set:"source_name":$source_map[$c.results_source_config_id]
            |set:"match":$match_brief
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
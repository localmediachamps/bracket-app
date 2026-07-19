// Lists results_source_config rows for a tournament with per-config candidate
// counts by status bucket plus source health (GET /admin/tournaments/{id}/sources).
// Status buckets: detected = detected|parsed|normalized (still in the pipeline),
// needs_review, matched, approved = approved|auto_approved, rejected, conflict,
// failed. Configs per tournament are few, so this is an unpaginated list.
// List ingestion sources for a tournament with candidate status counts
query "admin/tournaments/{tournament_id}/sources" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int tournament_id
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
  
    db.query results_source_config {
      where = $db.results_source_config.tournament_id == $input.tournament_id
      sort = {results_source_config.created_at: "asc"}
      return = {type: "list"}
    } as $configs
  
    // One bounded scan of the tournament's candidates, bucketed in memory per
    // config to avoid N count queries
    db.query external_result_candidate {
      where = $db.external_result_candidate.tournament_id == $input.tournament_id
      return = {type: "list"}
      output = ["id", "results_source_config_id", "status"]
    } as $all_candidates
  
    var $items {
      value = []
    }
  
    foreach ($configs) {
      each as $cfg {
        var $cfg_candidates {
          value = $all_candidates|filter:($$.results_source_config_id == $cfg.id)
        }
      
        var $count_detected {
          value = $cfg_candidates|filter:(($$.status == "detected") || ($$.status == "parsed") || ($$.status == "normalized"))|count
        }
      
        var $count_needs_review {
          value = $cfg_candidates|filter:($$.status == "needs_review")|count
        }
      
        var $count_matched {
          value = $cfg_candidates|filter:($$.status == "matched")|count
        }
      
        var $count_approved {
          value = $cfg_candidates|filter:(($$.status == "approved") || ($$.status == "auto_approved"))|count
        }
      
        var $count_rejected {
          value = $cfg_candidates|filter:($$.status == "rejected")|count
        }
      
        var $count_conflict {
          value = $cfg_candidates|filter:($$.status == "conflict")|count
        }
      
        var $count_failed {
          value = $cfg_candidates|filter:($$.status == "failed")|count
        }
      
        var $row {
          value = $cfg
            |set:"candidate_counts":```
              {
                detected    : $count_detected
                needs_review: $count_needs_review
                matched     : $count_matched
                approved    : $count_approved
                rejected    : $count_rejected
                conflict    : $count_conflict
                failed      : $count_failed
              }
              ```
        }
      
        array.push $items {
          value = $row
        }
      }
    }
  }

  response = {items: $items, total: $items|count}
}
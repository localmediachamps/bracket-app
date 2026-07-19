// Lists ingestion_conflict rows for a tournament, newest first
// (GET /admin/tournaments/{id}/conflicts?status=open). Each row is enriched
// with a brief of its candidate (source fields + confidences) and, when
// bracket_match_id is set, a brief of the match it concerns. Conflicts are
// few and this is a low-traffic admin review screen, so the briefs are loaded
// per row with single-record gets.
// List ingestion conflicts for a tournament with candidate and match briefs
query "admin/tournaments/{tournament_id}/conflicts" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int tournament_id
  
    // open | resolved | dismissed
    text? status?=open filters=trim|lower
  
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
  
    var $conflict_statuses {
      value = ["open", "resolved", "dismissed"]
    }
  
    precondition ($conflict_statuses|some:$$ == $input.status) {
      error_type = "inputerror"
      error = "status must be one of: " ~ ($conflict_statuses|join:", ") ~ "."
    }
  
    db.query ingestion_conflict {
      where = $db.ingestion_conflict.tournament_id == $input.tournament_id && $db.ingestion_conflict.status == $input.status
      sort = {ingestion_conflict.created_at: "desc"}
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $page_result
  
    var $items {
      value = []
    }
  
    foreach ($page_result.items) {
      each as $conflict {
        var $candidate_brief {
          value = null
        }
      
        db.get external_result_candidate {
          field_name = "id"
          field_value = $conflict.candidate_id
        } as $conflict_candidate
      
        conditional {
          if ($conflict_candidate != null) {
            var.update $candidate_brief {
              value = {
                id                 : $conflict_candidate.id
                status             : $conflict_candidate.status
                source_weight_class: $conflict_candidate.source_weight_class
                source_round       : $conflict_candidate.source_round
                source_winner      : $conflict_candidate.source_winner
                source_loser       : $conflict_candidate.source_loser
                source_score       : $conflict_candidate.source_score
                source_victory_type: $conflict_candidate.source_victory_type
                overall_confidence : $conflict_candidate.overall_confidence
                matched_match_id   : $conflict_candidate.matched_match_id
              }
            }
          }
        }
      
        var $match_brief {
          value = null
        }
      
        conditional {
          if ($conflict.bracket_match_id != null) {
            db.get bracket_match {
              field_name = "id"
              field_value = $conflict.bracket_match_id
            } as $conflict_match
          
            conditional {
              if ($conflict_match != null) {
                var.update $match_brief {
                  value = {
                    id                       : $conflict_match.id
                    round_code               : $conflict_match.round_code
                    round_label              : $conflict_match.round_label
                    match_number             : $conflict_match.match_number
                    weight_class_id          : $conflict_match.weight_class_id
                    match_status             : $conflict_match.match_status
                    actual_winner_wrestler_id: $conflict_match.actual_winner_wrestler_id
                    actual_loser_wrestler_id : $conflict_match.actual_loser_wrestler_id
                    victory_type             : $conflict_match.victory_type
                    actual_score             : $conflict_match.actual_score
                  }
                }
              }
            }
          }
        }
      
        var $row {
          value = $conflict
            |set:"candidate":$candidate_brief
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
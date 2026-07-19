// Bulk-approves external_result_candidate rows for a tournament
// (POST /admin/tournaments/{id}/candidates/bulk-approve). Each candidate runs
// through approve_candidate inside try_catch, so only rows passing the strict
// checks (approvable status, resolved winner, matched match, apply_match_result
// guards) are applied — failures are collected per id and never abort the
// batch. Candidates must belong to the path tournament. When at least one
// approval applied, the tournament is rescored once at the end.
// Bulk-approve candidates; per-item failures are collected, batch never aborts
query "admin/tournaments/{tournament_id}/candidates/bulk-approve" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int tournament_id
  
    // external_result_candidate ids to approve (max 200 per call)
    int[] candidate_ids
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
  
    precondition (($input.candidate_ids|count) > 0) {
      error_type = "inputerror"
      error = "candidate_ids must not be empty."
    }
  
    precondition (($input.candidate_ids|count) <= 200) {
      error_type = "inputerror"
      error = "Bulk approve is capped at 200 candidates per call."
    }
  
    var $applied {
      value = 0
    }
  
    var $failed {
      value = []
    }
  
    foreach ($input.candidate_ids) {
      each as $cid {
        try_catch {
          try {
            db.get external_result_candidate {
              field_name = "id"
              field_value = $cid
            } as $bulk_candidate
          
            conditional {
              if (($bulk_candidate == null) || ($bulk_candidate.tournament_id != $input.tournament_id)) {
                throw {
                  name = "notfound"
                  value = "Candidate " ~ $cid ~ " not found in this tournament."
                }
              }
            }
          
            function.run "" {
              input = {candidate_id: $cid, actor_id: $auth.id}
            } as $bulk_approve
          
            math.add $applied {
              value = 1
            }
          }
        
          catch {
            array.push $failed {
              value = {id: $cid, error: $error.message}
            }
          }
        }
      }
    }
  
    // One rescore at the end when anything was applied
    conditional {
      if ($applied > 0) {
        function.run rescore_tournament {
          input = {tournament_id: $input.tournament_id}
        } as $bulk_rescore
      }
    }
  }

  response = {applied: $applied, failed: $failed}
}
// Approves an external_result_candidate and applies it as an official match
// result (ingestion pipeline step 4: candidate -> official result).
// Admin overrides ({winner_competitor_id, matched_match_id, victory_type,
// score}) are folded into the normalized payload before precondition checks.
// The write goes through apply_match_result so advancement, history, version
// guards and audit all stay in one place; notes record the source name, and a
// match that was already complete is treated as a correction with reason
// "External result correction via ingestion".
// If apply_match_result raises its 409:DOWNSTREAM_COMPLETE error the candidate
// is parked in status "conflict" and the error is rethrown for the caller.
// On success the candidate becomes approved|auto_approved, any open
// ingestion_conflict rows for it are resolved as "approved", and an audit row
// (result_candidate_approved) is written. Rescoring is the caller's job.
// Approve a candidate and apply it as the official result of its matched match
function approve_candidate {
  input {
    // external_result_candidate.id to approve
    int candidate_id
  
    // Admin performing the approval (null for auto-approval)
    int? actor_id?
  
    // true when triggered by a source auto-approval policy
    bool? auto?
  
    // Optional admin edits applied before approval:
    // {winner_competitor_id?, matched_match_id?, victory_type?, score?}
    json? override?
  }

  stack {
    db.get external_result_candidate {
      field_name = "id"
      field_value = $input.candidate_id
    } as $candidate
  
    precondition ($candidate != null) {
      error_type = "notfound"
      error = "Candidate not found."
    }
  
    var $approvable_statuses {
      value = ["matched", "needs_review", "conflict"]
    }
  
    precondition ($approvable_statuses|some:$$ == $candidate.status) {
      error_type = "inputerror"
      error = "Candidate is not in an approvable state (current: " ~ $candidate.status ~ ")."
    }
  
    var $payload {
      value = $candidate.normalized_payload|first_notnull:{}
    }
  
    var $matched_match_id {
      value = $candidate.matched_match_id
    }
  
    // Admin overrides fold into the payload before any checks
    conditional {
      if ($input.override != null) {
        var.update $payload {
          value = $payload
            |set_ifnotnull:"winner_competitor_id":($input.override|get:"winner_competitor_id":null)
        }
      
        var.update $payload {
          value = $payload
            |set_ifnotnull:"victory_type":($input.override|get:"victory_type":null)
        }
      
        var.update $payload {
          value = $payload
            |set_ifnotnull:"score":($input.override|get:"score":null)
        }
      
        conditional {
          if (($input.override|get:"matched_match_id":null) != null) {
            var.update $matched_match_id {
              value = $input.override|get:"matched_match_id":null
            }
          }
        }
      }
    }
  
    var $winner_competitor_id {
      value = $payload|get:"winner_competitor_id":null
    }
  
    precondition ($matched_match_id != null) {
      error_type = "inputerror"
      error = "Candidate has no matched match to apply — match it first or pass override.matched_match_id."
    }
  
    precondition ($winner_competitor_id != null) {
      error_type = "inputerror"
      error = "Candidate has no resolved winner — fix identity first or pass override.winner_competitor_id."
    }
  
    db.get bracket_match {
      field_name = "id"
      field_value = $matched_match_id
    } as $match
  
    precondition ($match != null) {
      error_type = "notfound"
      error = "Matched bracket_match not found."
    }
  
    // Source name for the result notes (config may have been deleted; the
    // candidate survives as history)
    db.get results_source_config {
      field_name = "id"
      field_value = $candidate.results_source_config_id
    } as $source_config
  
    var $source_name {
      value = "external source"
    }
  
    conditional {
      if ($source_config != null) {
        var.update $source_name {
          value = $source_config.name|first_notnull:"external source"
        }
      }
    }
  
    // Applying onto an already-complete match is a correction and needs a reason
    var $change_reason {
      value = null
    }
  
    conditional {
      if (($match.match_status == "complete") || ($match.match_status == "corrected")) {
        var.update $change_reason {
          value = "External result correction via ingestion"
        }
      }
    }
  
    var $applied {
      value = false
    }
  
    var $apply_error {
      value = null
    }
  
    try_catch {
      try {
        function.run apply_match_result {
          input = {
            bracket_match_id  : $match.id
            actor_id          : $input.actor_id
            winner_wrestler_id: $winner_competitor_id
            match_status      : "complete"
            notes             : ("Imported from " ~ $source_name)
            victory_type      : $payload|get:"victory_type":null
            score             : $payload|get:"score":null
            change_reason     : $change_reason
          }
        } as $apply_result
      
        var.update $applied {
          value = true
        }
      }
    
      catch {
        var.update $apply_error {
          value = $error.message
        }
      }
    }
  
    conditional {
      if ($applied == false) {
        // A 409:DOWNSTREAM_COMPLETE from apply_match_result means a downstream
        // match is already finished — park the candidate as a conflict so an
        // admin can correct downstream first, then rethrow for the caller
        conditional {
          if (($apply_error|first_notnull:"")|icontains:"DOWNSTREAM_COMPLETE") {
            db.edit external_result_candidate {
              field_name = "id"
              field_value = $candidate.id
              data = {status: "conflict"}
            } as $conflicted_candidate
          }
        }
      
        throw {
          name = "standard"
          value = $apply_error
            |first_notnull:"apply_match_result failed."
        }
      }
    }
  
    var $final_status {
      value = $input.auto ? "auto_approved" : "approved"
    }
  
    db.edit external_result_candidate {
      field_name = "id"
      field_value = $candidate.id
      data = {
        status            : $final_status
        matched_match_id  : $matched_match_id
        normalized_payload: $payload
        reviewed_at       : "now"
        reviewed_by       : $input.actor_id
      }
    } as $updated_candidate
  
    // Resolve any open conflicts for this candidate as approved
    db.query ingestion_conflict {
      where = $db.ingestion_conflict.candidate_id == $candidate.id && $db.ingestion_conflict.status == "open"
      return = {type: "list"}
    } as $open_conflicts
  
    foreach ($open_conflicts) {
      each as $oc {
        db.edit ingestion_conflict {
          field_name = "id"
          field_value = $oc.id
          data = {
            status     : "resolved"
            resolution : "approved"
            resolved_by: $input.actor_id
            resolved_at: "now"
          }
        } as $resolved_conflict
      }
    }
  
    function.run audit {
      input = {
        actor_id   : $input.actor_id
        entity_type: "external_result_candidate"
        entity_id  : $candidate.id
        action     : "result_candidate_approved"
        new_value  : {
        match_id : $matched_match_id
        winner_id: $winner_competitor_id
        auto     : $input.auto
      }
      }
    } as $audit_row
  
    var $result {
      value = {candidate: $updated_candidate, applied: true}
    }
  }

  response = $result
}
// Rejects one external_result_candidate (POST /admin/candidates/{id}/reject).
// Only candidates that were never applied can be rejected — an approved or
// auto_approved candidate already wrote an official result and must be
// corrected through the match result endpoints instead. Audited
// (result_candidate_rejected) with the optional reason in metadata.
// Reject a candidate that should not become an official result
query "admin/candidates/{id}/reject" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // external_result_candidate ID
    int id
  
    // Optional reason for the rejection (kept in the audit metadata)
    text? reason? filters=trim
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get external_result_candidate {
      field_name = "id"
      field_value = $input.id
    } as $candidate
  
    precondition ($candidate != null) {
      error_type = "notfound"
      error = "Candidate not found."
    }
  
    var $rejectable_statuses {
      value = [
        "detected"
        "parsed"
        "normalized"
        "matched"
        "needs_review"
        "conflict"
        "failed"
      ]
    }
  
    precondition ($rejectable_statuses|some:$$ == $candidate.status) {
      error_type = "inputerror"
      error = "Only unapplied candidates can be rejected (current: " ~ $candidate.status ~ ")."
    }
  
    db.edit external_result_candidate {
      field_name = "id"
      field_value = $candidate.id
      data = {
        status     : "rejected"
        reviewed_at: "now"
        reviewed_by: $auth.id
      }
    } as $updated_candidate
  
    function.run audit {
      input = {
        actor_id      : $auth.id
        entity_type   : "external_result_candidate"
        entity_id     : $candidate.id
        action        : "result_candidate_rejected"
        previous_value: {status: $candidate.status}
        new_value     : {status: "rejected"}
        metadata      : {reason: $input.reason}
      }
    } as $audit_row
  }

  response = $updated_candidate
}
// Approves one external_result_candidate and applies it as the official match
// result (POST /admin/candidates/{id}/approve). Optional override lets the
// admin edit {winner_competitor_id, matched_match_id, victory_type, score}
// before applying. The tournament is rescored inline afterwards (MVP scale).
// approve_candidate's 409 DOWNSTREAM_COMPLETE error is NOT caught here — it
// propagates to the caller so the admin knows to correct downstream first.
// Approve a candidate, apply its result, and rescore the tournament
query "admin/candidates/{id}/approve" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // external_result_candidate ID
    int id
  
    // Optional admin edits applied before approval:
    // {winner_competitor_id?, matched_match_id?, victory_type?, score?}
    json? override?
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    // Conflict errors (e.g. 409 DOWNSTREAM_COMPLETE) bubble up as-is
    function.run approve_candidate {
      input = {
        candidate_id: $input.id
        actor_id    : $auth.id
        override    : $input.override
      }
    } as $approve_result
  
    // Inline rescore of the whole tournament (MVP scale)
    function.run rescore_tournament {
      input = {tournament_id: $approve_result.candidate.tournament_id}
    } as $rescore_summary
  }

  response = {
    candidate: $approve_result.candidate
    applied  : $approve_result.applied
    rescored : true
  }
}
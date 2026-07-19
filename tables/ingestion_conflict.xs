table ingestion_conflict {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int tournament_id
  
    // bracket_match.id the conflict concerns, if identified
    int bracket_match_id?
  
    // FK to external_result_candidate.id
    int candidate_id
  
    // existing_result | different_winner | ambiguous_match | identity_uncertain | duplicate
    text conflict_type
  
    // snapshot of current bracket_match result values
    json existing_value?
  
    // snapshot of the candidate's proposed values
    json candidate_value?
  
    // open | resolved | dismissed
    text status?=open
  
    // free-text note describing how the conflict was resolved
    text resolution?
  
    int resolved_by?
    timestamp resolved_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "status", op: "asc"}]}
  ]
}
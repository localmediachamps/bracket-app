table external_result_candidate {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int results_source_config_id
    int tournament_id
  
    // stable dedupe key from source, e.g. sha1 of weight + sorted names + event
    text external_match_key
  
    // raw fields exactly as extracted from the source
    text source_weight_class?
  
    text source_round?
    text source_winner?
    text source_winner_school?
    text source_loser?
    text source_loser_school?
    text source_score?
    text source_victory_type?
  
    // {weight_class_id?, winner_competitor_id?, loser_competitor_id?, victory_type?, score?}
    json normalized_payload?
  
    // bracket_match.id once matched (null until then)
    int matched_match_id?
  
    decimal extraction_confidence?
    decimal identity_confidence?
    decimal match_confidence?
    decimal overall_confidence?
  
    // detected | parsed | normalized | matched | needs_review | approved |
    // auto_approved | rejected | conflict | superseded | failed
    text status?=detected
  
    // raw text/html fragment the candidate was extracted from (debugging)
    text raw_fragment?
  
    timestamp reviewed_at?
    int reviewed_by?
  
    // when the match actually happened per the source, if known
    timestamp occurred_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {
      type : "btree"
      field: [{name: "results_source_config_id", op: "asc"}]
    }
    {type: "btree", field: [{name: "status", op: "asc"}]}
    {
      type : "btree|unique"
      field: [
        {name: "results_source_config_id", op: "asc"}
        {name: "external_match_key", op: "asc"}
      ]
    }
  ]
}
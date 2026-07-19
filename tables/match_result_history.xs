table match_result_history {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int bracket_match_id
    int tournament_id
  
    // matches bracket_match.version after the write
    int version
  
    int winner_wrestler_id
    int loser_wrestler_id
    text score?
    text victory_type?
    text match_status
  
    // entered | corrected | cleared
    text change_type
  
    // required for corrections
    text change_reason?
  
    // FK to user.id — admin who made the change
    int changed_by?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [
        {name: "bracket_match_id", op: "asc"}
        {name: "version", op: "desc"}
      ]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
  ]
}
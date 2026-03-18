table user_pick {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp updated_at?=now
    int user_bracket_id
  
    // denormalized for efficient querying
    int user_id
  
    int tournament_id
    int bracket_match_id
    int picked_wrestler_id
  
    // set after scoring runs
    bool is_correct?
  
    int points_earned?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "user_bracket_id", op: "asc"}
        {name: "bracket_match_id", op: "asc"}
      ]
    }
    {
      type : "btree"
      field: [{name: "user_bracket_id", op: "asc"}]
    }
    {
      type : "btree"
      field: [{name: "bracket_match_id", op: "asc"}]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
  ]
}
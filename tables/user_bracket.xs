table user_bracket {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int user_id
    int tournament_id
    decimal total_points?
    int rank?
    bool is_submitted?
    timestamp submitted_at?
  
    // draft | submitted | locked
    text status?=draft
  
    timestamp locked_at?
  
    // max additional points still achievable
    decimal possible_points?
  
    int correct_pick_count?
    int scored_pick_count?
  
    // correct champ_finals picks
    int champions_correct?
  
    int finalists_correct?
  
    // previous rank, for rank-change display
    int prev_rank?
  
    // scoring_config version this entry was last scored with
    int scoring_version?=1
  
    timestamp updated_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "user_id", op: "asc"}
        {name: "tournament_id", op: "asc"}
      ]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "total_points", op: "desc"}]}
  ]
}
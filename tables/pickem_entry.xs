table pickem_entry {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int user_id
    int tournament_id
  
    // draft | submitted | locked
    text status?=draft
  
    // salary-cap points spent
    int points_used?
  
    decimal tiebreaker_1?
    decimal tiebreaker_2?
    decimal tiebreaker_3?
    decimal total_points?
    int rank?
    int prev_rank?
    timestamp submitted_at?
    timestamp locked_at?
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
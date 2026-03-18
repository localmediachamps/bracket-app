table user_bracket {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int user_id
    int tournament_id
    int total_points?
    int rank?
    bool is_submitted?
    timestamp submitted_at?
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
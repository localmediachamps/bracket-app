table scoring_rule {
  auth = false

  schema {
    int id
    int tournament_id
    text round_code
    int points
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {
      type : "btree|unique"
      field: [
        {name: "tournament_id", op: "asc"}
        {name: "round_code", op: "asc"}
      ]
    }
  ]
}
table pickem_pick {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int pickem_entry_id
    int tournament_id
    int weight_class_id
    int wrestler_id
  
    // salary-cap cost from pickem_config.seed_costs
    int cost
  
    decimal points_earned?
  
    // placement / win / bonus points detail: {placement, wins, bonus}
    json breakdown?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "pickem_entry_id", op: "asc"}
        {name: "weight_class_id", op: "asc"}
      ]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {
      type : "btree"
      field: [{name: "pickem_entry_id", op: "asc"}]
    }
  ]
}
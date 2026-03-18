table weight_class {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int tournament_id
  
    // weight in lbs: 125 | 133 | 141 | 149 | 157 | 165 | 174 | 184 | 197 | 285
    int weight
  
    // status: pending | active | completed
    text status?=pending
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "weight", op: "asc"}]}
  ]
}
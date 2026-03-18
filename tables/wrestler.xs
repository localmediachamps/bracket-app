table wrestler {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int tournament_id
    int weight_class_id
  
    // seed 1-33 (NCAA DI has 33 qualifiers per weight)
    int seed
  
    text name
    text school
    text record?
  
    // original string from AI PDF parse for admin review
    text source_raw?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "weight_class_id", op: "asc"}]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "seed", op: "asc"}]}
  ]
}
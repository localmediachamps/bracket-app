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
  
    // lowercase, punctuation-stripped name for matching
    text normalized_name? filters=trim|lower
  
    bool withdrawn?
  
    // future identity layer link
    int? canonical_wrestler_id? {
      table = "canonical_wrestler"
    }
  
    json metadata?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "weight_class_id", op: "asc"}]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "seed", op: "asc"}]}
    {
      type : "btree|unique"
      field: [
        {name: "weight_class_id", op: "asc"}
        {name: "seed", op: "asc"}
      ]
    }
  ]
  guid = "n_p_D7Cw2p83rYg6mtghO6dFFO8"
}
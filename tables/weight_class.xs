table weight_class {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int tournament_id
  
    // weight in lbs: 125 | 133 | 141 | 149 | 157 | 165 | 174 | 184 | 197 | 285
    int weight
  
    // pending | active | completed
    text status?=pending
  
    // display name, e.g. "125 lbs"
    text name?
  
    int display_order?
  
    // bracket template, e.g. ncaa_33 | field_4 | field_8 | field_16 | field_32 | field_64 (default applied in code)
    text bracket_template?
  
    // championship field size, e.g. 32
    int bracket_size?
  
    int competitor_count?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "weight", op: "asc"}]}
    {
      type : "btree|unique"
      field: [
        {name: "tournament_id", op: "asc"}
        {name: "weight", op: "asc"}
      ]
    }
  ]
}
table group_membership {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int group_id
    int user_id
  
    // owner | admin | member
    text role?=member
  
    // active | pending | removed
    text status?=active
  
    timestamp joined_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "group_id", op: "asc"}, {name: "user_id", op: "asc"}]
    }
    {type: "btree", field: [{name: "user_id", op: "asc"}]}
    {type: "btree", field: [{name: "group_id", op: "asc"}]}
  ]
}
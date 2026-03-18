table tournament {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    text name
    int year
  
    // status: draft | active | locked | completed
    text status?=draft
  
    timestamp locks_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "year", op: "desc"}]}
    {type: "btree", field: [{name: "status", op: "asc"}]}
  ]
}
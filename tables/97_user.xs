table user {
  auth = true

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    text name filters=trim
    email? email filters=trim|lower
    password? password filters=min:8|minAlpha:1|minDigit:1
    bool is_admin?
  
    // url-safe handle; derive from email prefix when absent
    text username? filters=trim|lower
  
    text display_name? filters=trim
    text avatar_url?
    text bio?
    text favorite_school? filters=trim
    timestamp updated_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree|unique", field: [{name: "email", op: "asc"}]}
    {
      type : "btree|unique"
      field: [{name: "username", op: "asc"}]
    }
  ]
}
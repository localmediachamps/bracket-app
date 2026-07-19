table fantasy_group {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int tournament_id
    text name filters=trim
    text slug filters=trim|lower
    text description?
  
    // FK to user.id — group creator/owner
    int owner_id
  
    // public | unlisted | private
    text privacy?=private
  
    // 8-char Crockford base32 join code
    text invite_code
  
    int member_limit?
    int member_count?
  
    // emoji avatar, set in code (default applied by API layer)
    text avatar_emoji?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "invite_code", op: "asc"}]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "owner_id", op: "asc"}]}
    {
      type : "btree"
      field: [
        {name: "tournament_id", op: "asc"}
        {name: "slug", op: "asc"}
      ]
    }
  ]
}
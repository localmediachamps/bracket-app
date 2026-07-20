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
  
    // Opt out of appearing on public tournament-wide leaderboards entirely
    // (private group leaderboards are unaffected — those are visible only
    // to people the user already shares a group with)
    bool leaderboard_visible?=true
  
    // Which name to show when visible on the public leaderboard
    enum leaderboard_name_mode?="display_name" {
      values = ["display_name", "username"]
    }
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
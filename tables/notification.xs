table notification {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int user_id
  
    // tournament_open | deadline_soon | entry_incomplete | entry_locked | group_invite |
    // group_member_joined | tournament_started | rank_change | result_entered |
    // tournament_completed | group_final
    text type
  
    text title
    text body?
  
    // deep-link payload, e.g. {tournament_id, entry_id, group_id}
    json data?
  
    timestamp read_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [
        {name: "user_id", op: "asc"}
        {name: "created_at", op: "desc"}
      ]
    }
  ]
}
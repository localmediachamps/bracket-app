table audit_log {
  auth = false

  schema {
    int id
    timestamp created_at?=now
  
    // FK to user.id — who performed the action (null = system)
    int actor_id?
  
    // e.g. tournament | bracket_match | user_bracket | scoring_config
    text entity_type
  
    int entity_id?
  
    // e.g. publish | lock | result_entered | result_corrected | status_change
    text action
  
    json previous_value?
    json new_value?
    json metadata?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [
        {name: "entity_type", op: "asc"}
        {name: "entity_id", op: "asc"}
      ]
    }
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]
}
// Writes a single audit_log row and returns the created row.
// Used by admin mutations (status transitions, result entry, scoring config
// changes, competitor edits) per ARCHITECTURE.md sections 1 and 11.
// Append a row to audit_log and return it
function audit {
  input {
    // User performing the action (null for system tasks)
    int? actor_id?
  
    // Entity/table name, e.g. tournament, bracket_match
    text entity_type filters=trim|min:1
  
    // Primary key of the affected row
    int? entity_id?
  
    // Action verb, e.g. publish, lock, result_entered
    text action filters=trim|min:1
  
    // Snapshot before the change
    json? previous_value?
  
    // Snapshot after the change
    json? new_value?
  
    // Extra context (reason, request info, ...)
    json? metadata?
  }

  stack {
    db.add audit_log {
      data = {
        created_at    : "now"
        actor_id      : $input.actor_id
        entity_type   : $input.entity_type
        entity_id     : $input.entity_id
        action        : $input.action
        previous_value: $input.previous_value
        new_value     : $input.new_value
        metadata      : $input.metadata
      }
    } as $row
  }

  response = $row
  guid = "Wb79uDNc83ubd2RvO-GDRNpOUAw"
}
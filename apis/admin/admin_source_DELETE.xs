// Deletes a results_source_config (DELETE /admin/sources/{id}).
// Its external_result_candidate rows are intentionally kept: they retain the
// (now dangling) results_source_config_id as a historical reference of where
// each candidate came from. Audited (source_deleted).
// Delete an ingestion source config; candidates are kept as history
query "admin/sources/{id}" verb=DELETE {
  api_group = "admin"
  auth = "user"

  input {
    // results_source_config ID
    int id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get results_source_config {
      field_name = "id"
      field_value = $input.id
    } as $config
  
    precondition ($config != null) {
      error_type = "notfound"
      error = "Source config not found."
    }
  
    db.del results_source_config {
      field_name = "id"
      field_value = $input.id
    }
  
    function.run audit {
      input = {
        actor_id      : $auth.id
        entity_type   : "results_source_config"
        entity_id     : $config.id
        action        : "source_deleted"
        previous_value: {
        tournament_id: $config.tournament_id
        name         : $config.name
        source_type  : $config.source_type
      }
      }
    } as $audit_row
  }

  response = {deleted: true, id: $input.id}
}
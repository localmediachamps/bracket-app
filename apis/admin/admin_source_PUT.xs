// Updates a results_source_config (PUT /admin/sources/{id}). Any subset of the
// mutable fields may be sent; omitted fields are left untouched. Audited
// (source_updated) with a previous_value snapshot of the changed keys.
// Update an ingestion source config
query "admin/sources/{id}" verb=PUT {
  api_group = "admin"
  auth = "user"

  input {
    // results_source_config ID
    int id
  
    text? name? filters=trim|min:1
  
    // external_scrape | manual_upload | generic_html
    text? source_type? filters=trim|lower
  
    // Adapter implementation key
    text? adapter_name? filters=trim
  
    // review | auto_high_confidence | auto_all
    text? approval_policy? filters=trim|lower
  
    // overall_confidence at/above which auto_high_confidence applies (0..1)
    decimal? auto_approve_threshold?
  
    // Adapter params {season_id, event_id, tournament_id_external, base_url}
    json? configuration?
  
    int? update_interval_minutes? filters=min:1
  
    // Lower wins when multiple sources report the same match
    int? source_priority?
  
    bool? enabled?
  
    // healthy | degraded | failing | disabled
    text? health_status? filters=trim|lower
  
    text? last_error? filters=trim
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
  
    var $approval_policies {
      value = ["review", "auto_high_confidence", "auto_all"]
    }
  
    precondition (($input.approval_policy == null) || $approval_policies|some:$$ == $input.approval_policy) {
      error_type = "inputerror"
      error = "approval_policy must be one of: " ~ ($approval_policies|join:", ") ~ "."
    }
  
    precondition (($input.auto_approve_threshold == null) || (($input.auto_approve_threshold >= 0) && ($input.auto_approve_threshold <= 1))) {
      error_type = "inputerror"
      error = "auto_approve_threshold must be between 0 and 1."
    }
  
    var $health_statuses {
      value = ["healthy", "degraded", "failing", "disabled"]
    }
  
    precondition (($input.health_status == null) || $health_statuses|some:$$ == $input.health_status) {
      error_type = "inputerror"
      error = "health_status must be one of: " ~ ($health_statuses|join:", ") ~ "."
    }
  
    // Merge: any field the caller omitted keeps its existing value
    db.edit results_source_config {
      field_name = "id"
      field_value = $input.id
      data = {
        name                   : $input.name|first_notnull:$config.name
        source_type            : $input.source_type|first_notnull:$config.source_type
        adapter_name           : $input.adapter_name|first_notnull:$config.adapter_name
        approval_policy        : $input.approval_policy|first_notnull:$config.approval_policy
        auto_approve_threshold : $input.auto_approve_threshold|first_notnull:$config.auto_approve_threshold
        configuration          : $input.configuration|first_notnull:$config.configuration
        update_interval_minutes: $input.update_interval_minutes|first_notnull:$config.update_interval_minutes
        source_priority        : $input.source_priority|first_notnull:$config.source_priority
        enabled                : $input.enabled|first_notnull:$config.enabled
        health_status          : $input.health_status|first_notnull:$config.health_status
        last_error             : $input.last_error|first_notnull:$config.last_error
        updated_at             : "now"
      }
    } as $updated_config
  
    function.run audit {
      input = {
        actor_id      : $auth.id
        entity_type   : "results_source_config"
        entity_id     : $config.id
        action        : "source_updated"
        previous_value: {
        name           : $config.name
        source_type    : $config.source_type
        approval_policy: $config.approval_policy
        enabled        : $config.enabled
      }
        new_value     : {
        name           : $updated_config.name
        source_type    : $updated_config.source_type
        approval_policy: $updated_config.approval_policy
        enabled        : $updated_config.enabled
      }
      }
    } as $audit_row
  }

  response = $updated_config
  guid = "UdOhKLB8T950vJ0e2hWiqjfPQ2U"
}
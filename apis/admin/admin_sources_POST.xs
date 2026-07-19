// Creates a results_source_config for a tournament
// (POST /admin/tournaments/{id}/sources). Unprovided fields fall back to the
// schema defaults (source_type=trackwrestling, approval_policy=review,
// auto_approve_threshold=0.9, update_interval_minutes=15, enabled=true).
// configuration carries adapter params {season_id, event_id,
// tournament_id_external, base_url}. Audited (source_created).
// Create an ingestion source config for a tournament
query "admin/tournaments/{tournament_id}/sources" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int tournament_id
  
    // Human-readable label, e.g. "TrackWrestling — 2026 NCAA DI"
    text name filters=trim|min:1
  
    // trackwrestling | manual_upload | generic_html
    text? source_type? filters=trim|lower
  
    // Adapter implementation key, e.g. trackwrestling_event_matches
    text? adapter_name? filters=trim
  
    // review | auto_high_confidence | auto_all
    text? approval_policy? filters=trim|lower
  
    // overall_confidence at/above which auto_high_confidence applies (0..1)
    decimal? auto_approve_threshold?
  
    // Adapter params {season_id, event_id, tournament_id_external, base_url}
    json? configuration?
  
    // Poll cadence hint for the scraper
    int? update_interval_minutes? filters=min:1
  
    // Lower wins when multiple sources report the same match
    int? source_priority?
  
    bool? enabled?
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get tournament {
      field_name = "id"
      field_value = $input.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
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
  
    db.add results_source_config {
      data = {
        tournament_id          : $input.tournament_id
        name                   : $input.name
        created_by             : $auth.id
        source_type            : $input.source_type|first_notnull:"trackwrestling"
        adapter_name           : $input.adapter_name|first_notnull:"trackwrestling_event_matches"
        approval_policy        : $input.approval_policy|first_notnull:"review"
        auto_approve_threshold : $input.auto_approve_threshold|first_notnull:0.9
        configuration          : $input.configuration
        update_interval_minutes: $input.update_interval_minutes|first_notnull:15
        source_priority        : $input.source_priority|first_notnull:50
        enabled                : $input.enabled|first_notnull:true
      }
    } as $new_config
  
    function.run audit {
      input = {
        actor_id   : $auth.id
        entity_type: "results_source_config"
        entity_id  : $new_config.id
        action     : "source_created"
        new_value  : {
        tournament_id  : $input.tournament_id
        name           : $input.name
        source_type    : $new_config.source_type
        approval_policy: $new_config.approval_policy
      }
      }
    } as $audit_row
  }

  response = $new_config
}
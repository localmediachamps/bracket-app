table results_source_config {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int tournament_id
  
    // human-readable label, e.g. "TrackWrestling — 2026 NCAA DI"
    text name
  
    // trackwrestling | manual_upload | generic_html
    text source_type?=trackwrestling
  
    // adapter implementation key, e.g. trackwrestling_event_matches
    text adapter_name?="trackwrestling_event_matches"
  
    text adapter_version?
    int update_interval_minutes?=15
  
    // lower wins when multiple sources report the same match
    int source_priority?=50
  
    // review | auto_high_confidence | auto_all
    text approval_policy?=review
  
    // overall_confidence at/above which auto_high_confidence applies
    decimal auto_approve_threshold?="0.9"
  
    // adapter params: {season_id, event_id, tournament_id_external, teams_csv_path, base_url}
    json configuration?
  
    bool enabled?=true
    timestamp last_checked_at?
    timestamp last_successful_at?
  
    // healthy | degraded | failing | disabled
    text health_status?=healthy
  
    text last_error?
    int created_by?
    timestamp updated_at?=now
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "enabled", op: "asc"}]}
  ]
}
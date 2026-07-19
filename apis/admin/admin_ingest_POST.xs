// Scraper push endpoint: accepts a batch of raw result candidates for one
// source config (POST /admin/sources/{id}/ingest) and runs the ingestion
// pipeline via ingest_candidates (dedupe -> normalize -> match -> optional
// auto-approve). Batches are capped at 500 candidates inside the function.
// NOTE: callers are expected to throttle themselves to the source's
// update_interval_minutes cadence; add a redis.ratelimit guard here if
// scrapers ever push faster than that.
// Push a batch of raw result candidates into the ingestion pipeline
query "admin/sources/{id}/ingest" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // results_source_config ID
    int id
  
    // Raw candidates: [{external_match_key, source_weight_class, source_round,
    // source_winner, source_winner_school, source_loser, source_loser_school,
    // source_score, source_victory_type, raw_fragment?, occurred_at?,
    // extraction_confidence?}]
    json candidates
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
  
    function.run "" {
      input = {
        results_source_config_id: $input.id
        candidates              : $input.candidates
        actor_id                : $auth.id
      }
    } as $summary
  }

  response = $summary
}
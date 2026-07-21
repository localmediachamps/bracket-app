// Bulk upsert for wrestler_match_history, so re-running/correcting the
// external results scraper (e.g. adding a field we missed the first time)
// never again requires a manual CSV import through the Xano dashboard.
// Idempotent on source_match_id: re-sending the same match just updates it
// in place. Callers should batch a few hundred to ~1000 rows per call
// (scripts/results_scraper/push_match_history.py handles the batching) -
// this table has ~100k+ rows, so one giant request is not the shape.
query "admin/wrestler-match-history/upsert" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    object[1:1000] matches {
      schema {
        text source_match_id filters=trim
        text? winner_name_raw? filters=trim
        text? loser_name_raw? filters=trim
        text? winner_school_raw? filters=trim
        text? loser_school_raw? filters=trim
        text? winner_class_year_raw? filters=trim
        text? loser_class_year_raw? filters=trim
        text? weight_class? filters=trim
        text? victory_type? filters=trim
        text? score? filters=trim
        int? time_seconds?
        text? round_label? filters=trim
        text? round_sort_key? filters=trim
        text? level? filters=trim
        text? event_name? filters=trim
        text? event_series_name? filters=trim
        text? event_type? filters=trim
        text? event_id_external? filters=trim
        text? date_start_raw? filters=trim
        text? date_end_raw? filters=trim
        timestamp? occurred_at?
        decimal? extraction_confidence?
      }
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $processed_count { value = 0 }
    var $errors { value = [] }

    foreach ($input.matches) {
      each as $m {
        try_catch {
          try {
            db.add_or_edit "wrestler_match_history" {
              field_name = "source_match_id"
              field_value = $m.source_match_id
              data = {
                source_match_id: $m.source_match_id,
                winner_name_raw: $m.winner_name_raw,
                loser_name_raw: $m.loser_name_raw,
                winner_school_raw: $m.winner_school_raw,
                loser_school_raw: $m.loser_school_raw,
                winner_class_year_raw: $m.winner_class_year_raw,
                loser_class_year_raw: $m.loser_class_year_raw,
                weight_class: $m.weight_class,
                victory_type: $m.victory_type,
                score: $m.score,
                time_seconds: $m.time_seconds,
                round_label: $m.round_label,
                round_sort_key: $m.round_sort_key,
                level: $m.level,
                event_name: $m.event_name,
                event_series_name: $m.event_series_name,
                event_type: $m.event_type,
                event_id_external: $m.event_id_external,
                date_start_raw: $m.date_start_raw,
                date_end_raw: $m.date_end_raw,
                occurred_at: $m.occurred_at,
                extraction_confidence: $m.extraction_confidence
              }
            } as $row

            math.add $processed_count { value = 1 }
          }
          catch {
            array.push $errors { value = {source_match_id: $m.source_match_id, message: $error.message} }
          }
        }
      }
    }
  }

  response = {
    received: $input.matches|count
    processed: $processed_count
    error_count: $errors|count
    errors: $errors
  }
  guid = "b5Ua7IT9RafZHDPV8lVgLa10oLa"
}

// One row per historical match (dual meets and tournaments) pulled from an
// external public-results feed. Winner/loser link to canonical_wrestler when
// identity resolution succeeds; raw name/school text always kept as a
// fallback so a row is never lost to an unresolved match. source_match_id is
// unique so re-importing the same wrestler/event is idempotent (upsert, not
// duplicate). Note: raw match results are public factual data, but by policy
// this table intentionally has no field identifying which external provider
// they came from.
table wrestler_match_history {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? winner_canonical_wrestler_id? {
      table = "canonical_wrestler"
    }

    int? loser_canonical_wrestler_id? {
      table = "canonical_wrestler"
    }

    text winner_name_raw? filters=trim
    text loser_name_raw? filters=trim
    text winner_school_raw? filters=trim
    text loser_school_raw? filters=trim
    text winner_class_year_raw? filters=trim
    text loser_class_year_raw? filters=trim

    text weight_class? filters=trim
    text victory_type? filters=trim

    text round_label? filters=trim
    text round_sort_key? filters=trim
    text level? filters=trim

    text event_name? filters=trim
    text event_series_name? filters=trim

    enum? event_type? {
      values = ["dual", "tournament"]
    }

    text event_id_external? filters=trim

    // Dates arrive in mixed formats (date-only "20260319" or
    // date+time "202603191247") - kept as raw text; a normalized timestamp
    // is derived separately once the format is fully nailed down.
    text date_start_raw? filters=trim
    text date_end_raw? filters=trim
    timestamp? occurred_at?

    text source_match_id? filters=trim
    decimal extraction_confidence?=1

    json? raw_row?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "source_match_id", op: "asc"}]}
    {type: "btree", field: [{name: "winner_canonical_wrestler_id", op: "asc"}]}
    {type: "btree", field: [{name: "loser_canonical_wrestler_id", op: "asc"}]}
    {type: "btree", field: [{name: "occurred_at", op: "desc"}]}
  ]
  guid = "OYn6sYaLSLh19ffDgLHKiaSHcm8"
}

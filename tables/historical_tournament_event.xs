// Real regular-season (and postseason) tournament events, derived from
// wrestler_match_history's own event_name/event_type=="tournament" rows -
// same reconciliation pattern as dual_meet (see functions/analytics/
// reconcile_historical_tournament_events.xs), NOT hand-scraped. This is the
// browsable "what tournaments actually happened, and when" calendar a
// commissioner needs to evaluate before choosing marquee tournament weeks -
// see the 2026-07-24 marquee-scoring-design discussion (roster-scored vs.
// real bracket/pick'em depends on how consistently teams' STARTERS actually
// attend a given event, which this table + historical_tournament_event_team
// exists to let Garrett actually see before deciding).
table historical_tournament_event {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    text name filters=trim
    text? series_name? filters=trim

    // Unique per real-world event - upsert key, same idempotency pattern as
    // dual_meet.source_match_key
    text event_id_external filters=trim

    timestamp starts_at
    timestamp ends_at

    int? match_count?
    int? team_count?

    // e.g. "2025-26" - same label convention used everywhere else
    text? season_label? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "event_id_external", op: "asc"}]}
    {type: "btree", field: [{name: "starts_at", op: "asc"}]}
    {type: "btree", field: [{name: "season_label", op: "asc"}]}
  ]
  guid = "Xn8mVo3ZkQs5LcRpYt6HbJd2FgWe4"
}

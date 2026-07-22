// Career/season-spanning team entity for the historical-records library.
// Distinct from any per-tournament team text fields elsewhere — this is the
// "real school" a canonical_wrestler currently belongs to, and what team
// profile pages are built from.
table canonical_team {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    text name filters=trim
    text abbrev? filters=trim
    text state? filters=trim
    text conference? filters=trim

    // External feed's numeric team id — a matching hint, not trusted as a
    // stable unique key (unconfirmed whether it's stable across seasons;
    // the same real team was observed under two different ids in one
    // exploratory session on 2026-07-20).
    text external_team_id? filters=trim

    // Official athletics department wrestling roster page - a reference
    // link for the team profile page, not a data source we scrape (see
    // compliance note re: results provider). Populated by hand/research,
    // not guaranteed for every team.
    text roster_url? filters=trim

    // Official athletics department wrestling schedule page - same
    // reference-link convention as roster_url. Kept even though app-side
    // schedule ingestion isn't built yet, so teams already have a place to
    // point users once new-season schedules are released.
    text schedule_url? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "name", op: "asc"}]}
    {type: "btree", field: [{name: "external_team_id", op: "asc"}]}
  ]
  guid = "Rfdq_QGgsf2rF3jQ7xvqGMj7evE"
}

// Career-spanning wrestler identity for the historical-records library —
// one row per real person, not per tournament. tables/wrestler.xs's existing
// (currently unused) canonical_wrestler_id field is the link: when a bracket
// is imported, each per-tournament wrestler row gets matched to one of these
// so the platform can surface real match history, records, and profiles.
table canonical_wrestler {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?

    text display_name filters=trim
    text legal_first_name? filters=trim
    text legal_last_name? filters=trim
    date? birthdate?

    enum? gender? {
      values = ["M", "F"]
    }

    int? current_team_id? {
      table = "canonical_team"
    }

    // External-feed identifiers — matching hints, not trusted as stable
    // unique keys until cross-season stability is confirmed empirically.
    // Prefer matching on legal name + birthdate + school history when in
    // doubt.
    text external_wrestler_id? filters=trim
    text external_wrestler_short_id? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "external_wrestler_id", op: "asc"}]}
    {type: "btree", field: [{name: "current_team_id", op: "asc"}]}
    {
      type : "btree"
      field: [
        {name: "legal_last_name", op: "asc"}
        {name: "legal_first_name", op: "asc"}
      ]
    }
  ]
  guid = "nDOsuahlo_f28-G6VScI51q7t-s"
}

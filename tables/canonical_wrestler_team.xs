// Many-to-many join between canonical_wrestler and canonical_team, with the
// season(s) each link is from - a wrestler transferring schools (very common:
// NIL-driven moves after a breakout season, grad-transfers for a final year
// of eligibility, etc.) gets ONE canonical_wrestler row with multiple rows
// here, one per school they actually competed for, each carrying which
// season. This is a career/roster history view - it does NOT change how
// match-level results are filtered (wrestler_match_history's own
// winner/loser_school_raw + occurred_at already scope each match to the
// right school/season on their own).
table canonical_wrestler_team {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int canonical_wrestler_id {
      table = "canonical_wrestler"
    }

    int canonical_team_id {
      table = "canonical_team"
    }

    // e.g. "2024-25" - matches the season labels already used across the
    // results scraper (scripts/results_scraper/ncaa_d1_matches_*.csv)
    text season_label filters=trim

    int? match_count?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "canonical_wrestler_id", op: "asc"}
        {name: "canonical_team_id", op: "asc"}
        {name: "season_label", op: "asc"}
      ]
    }
    {type: "btree", field: [{name: "canonical_team_id", op: "asc"}]}
  ]
  guid = "Yq3nTvXm7BwLpKzRhCo9SjF2uAe"
}

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

    // Manual admin correction to the "who's the starter at this weight"
    // heuristic (computed live from season match counts wherever it's
    // shown - most matches at a weight is a solid proxy for who the coach
    // actually sends out, real teams are usually consistent about it).
    // Null means "trust the heuristic"; true/false forces it regardless of
    // match count (e.g. a true freshman phenom who's started every dual
    // despite fewer total matches than a senior teammate who wrestled more
    // non-conference tournaments).
    bool? is_starter_override?

    // Cached result of the same heuristic (most matches this season at this
    // weight, overridden by is_starter_override when set) - refreshed by
    // tasks/compute_starter_tags.xs. Stored rather than computed live on
    // every read because several list views (waiver wire, trade research)
    // need "is this wrestler a starter" for hundreds of wrestlers across
    // dozens of teams at once, where recomputing per-team live (as
    // results/teams/{id} still does for its single-team detail view) would
    // mean redoing every team's full match-history scan on every page load.
    bool? is_starter?
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

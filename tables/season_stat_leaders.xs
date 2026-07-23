// Precomputed per-season stat-leader leaderboards, derived from
// wrestler_match_history by tasks/compute_season_stat_leaders.xs. One row
// per season_label (the same fixed academic-year labels used elsewhere,
// e.g. results/wrestlers/{id} - see that endpoint's season_bounds comment).
// Precomputed rather than computed live because the source table is ~100k
// rows and a per-wrestler-per-season tally requires a full scan; the API
// endpoint just reads this cached row.
table season_stat_leaders {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    text season_label filters=trim

    // Each entry: {wrestler_id, display_name, team_name, weight_class, count}
    json? most_wins?
    json? most_pins?
    json? most_tech_falls?

    // Each entry: {match_id, wrestler_name, opponent_name, weight_class, time_seconds, event_name, occurred_at}
    json? fastest_falls?

    // Each entry: {match_id, winner_name, loser_name, weight_class, score, total_points, event_name, occurred_at}
    json? highest_scoring_matches?

    int? matches_considered?
    timestamp? computed_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "season_label", op: "asc"}]}
  ]
  guid = "HeRi6FORPXL-YkQjX02cwPRPbkY"
}

// Materialized cross-tournament ledger that the platform master leaderboard
// sums from - one row per (user, tournament, source_type), written whenever
// that entry gets ranked/graded. Deliberately NOT computed live on every
// leaderboard page load (summing potentially thousands of rows per user on
// every request doesn't scale) - mirrors the exact role
// season_week_tournament_result plays for the fantasy league feature.
//
// Two independent scoring paths write into this same table (see
// get_default_platform_leaderboard_config.xs and the plan doc):
//   percentile - bracket/pick'em. Ranked against the tournament's own field
//     size, so it scales correctly whether an event has 8 entrants or 5,000.
//     rank_in_tournament/entrants/percentile are populated, rubric_tier null.
//   rubric - dual-meet-picks. Graded against a fixed absolute correctness
//     rubric, not against other entrants at all (many dual-meet submissions
//     overlap since there's much less variation possible than a full
//     bracket). rubric_tier is populated, rank_in_tournament/entrants/
//     percentile null. Uses dual_meet_id instead of tournament_id, and
//     year is copied from dual_meet.year instead of tournament.year.
//
// Only genuinely competitive (submitted|locked) entries ever get a row here -
// drafts never count toward the master leaderboard.
table platform_leaderboard_entry {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? user_id? {
      table = "user"
    }

    int? tournament_id? {
      table = "tournament"
    }

    // Populated instead of tournament_id when source_type == "dual_meet"
    int? dual_meet_id? {
      table = "dual_meet"
    }

    // bracket | pickem | dual_meet
    enum source_type {
      values = ["bracket", "pickem", "dual_meet"]
    }

    // percentile | rubric - which mechanism produced this row
    enum scoring_path {
      values = ["percentile", "rubric"]
    }

    // percentile path only (bracket/pickem)
    int? rank_in_tournament?
    int? entrants?
    decimal? percentile?

    // rubric path only (dual_meet, once built) - e.g. "perfect_card",
    // "all_winners", "9_of_10"
    text? rubric_tier? filters=trim

    // Always populated regardless of path - the number that gets summed
    // into a user's master leaderboard total
    decimal points_awarded?=0

    // Copied from tournament.year at write time so year-scoped queries
    // never need a join back to tournament
    int year
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "user_id", op: "asc"}
        {name: "tournament_id", op: "asc"}
        {name: "dual_meet_id", op: "asc"}
        {name: "source_type", op: "asc"}
      ]
    }
    {type: "btree", field: [{name: "user_id", op: "asc"}, {name: "year", op: "asc"}]}
    {type: "btree", field: [{name: "year", op: "asc"}]}
  ]
  guid = "Hq3wTmXs6RvLpYoNcVe8FgB2iAd"
}

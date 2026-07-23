// A single dual meet event (two teams, one weight class at a time) that
// users predict winner + victory-type for. Populated either by hand (a real
// upcoming dual) or auto-generated from real historical wrestler_match_history
// rows for testing/backfill - in the latter case the real results are stored
// on dual_meet_weight_slot as a hidden "answer key" until the dual meet is
// locked and scored, exactly like a real future dual meet would be.
table dual_meet {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    text name filters=trim
    int year

    // url-safe slug from name+year
    text slug filters=trim|lower

    int? home_canonical_team_id? {
      table = "canonical_team"
    }

    int? away_canonical_team_id? {
      table = "canonical_team"
    }

    // Raw text fallback - always populated even when canonical team linking
    // isn't resolved
    text home_team_name filters=trim
    text away_team_name filters=trim

    date? event_date?
    timestamp? occurred_at?

    // prediction deadline - entries lock when this passes
    timestamp locks_at?

    // state machine: draft | open | locked | scoring | completed | cancelled
    text status?=draft

    // public | unlisted
    text visibility?=public

    bool show_pick_percentages?

    int created_by?

    // dirty flag for task-based scoring
    bool needs_rescore?

    // denormalized count of submitted+locked entries
    int entry_count?

    // Idempotency hint when auto-created from historical data - not a DB
    // uniqueness constraint (checked manually before insert instead, so a
    // deliberate re-creation for testing doesn't hit a hard conflict)
    text? source_match_key? filters=trim

    // True for a dual meet reconciled in bulk from real historical
    // wrestler_match_history rows (see functions/analytics/
    // reconcile_dual_meets_for_range.xs) purely for browsing past results -
    // never enters the predict/pick flow, unlike an admin-seeded or
    // from-history dual meet meant for QA/testing picks. The frontend uses
    // this to skip the whole Predict/Leaderboard UI and just show the
    // final result.
    bool? is_historical?

    // Final NCAA dual-meet team score (sum of each side's bout point
    // values - decision=3, major=4, tech fall=5, fall/forfeit/default/
    // disqualification=6). Only populated once the dual is complete.
    int? home_score?
    int? away_score?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "slug", op: "asc"}]}
    {type: "btree", field: [{name: "status", op: "asc"}]}
    {type: "btree", field: [{name: "year", op: "desc"}]}
    {type: "btree", field: [{name: "source_match_key", op: "asc"}]}
  ]
  guid = "ieu8sULfV_eWrCRPaXn_Yohd5e8"
}

// The live/scheduled snake-draft session state - reused for two contexts:
// the one-time preseason league draft (season_week_id null, permanent
// roster_slot rows written) AND a tournament-only mini-draft scoped to one
// season_week (season_week_id set, picks are draft_pick-only and never
// touch roster_slot, so the season-long roster is untouched and reverts
// automatically once the tournament week is over). Same turn engine, same
// draft room UI, for both - see leagues_draft_*_POST.xs.
//
// Uniqueness ("one preseason draft per league", "one mini-draft per league
// per week") is enforced at the application layer, not a DB index - a
// composite unique index across a nullable season_week_id would treat every
// NULL as distinct and not actually block duplicates.
table draft {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? league_id? {
      table = "league"
    }

    // Null = the preseason league-wide draft. Set = a tournament-only
    // mini-draft scoped to that season_week (see season_week.tournament_game_mode
    // == "tournament_draft").
    int? season_week_id? {
      table = "season_week"
    }

    enum status?="scheduled" {
      values = ["scheduled", "in_progress", "paused", "complete"]
    }

    timestamp scheduled_at?
    int current_pick_number?

    int? current_membership_id? {
      table = "league_membership"
    }

    // Preseason: league.roster_starter_slots + league.roster_alternate_slots.
    // Tournament mini-draft: that tournament's weight_class count (no alternates).
    int rounds?

    // Nullable - v1 ships without enforced pick timers
    int? pick_time_limit_seconds?
    timestamp? current_pick_deadline?

    // Materialized round-1 membership-id order, reversed each round (snake)
    json? snake_order?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "league_id", op: "asc"}]}
    {type: "btree", field: [{name: "season_week_id", op: "asc"}]}
  ]
  guid = "eJ86pwuKfB_00Y-QsjE__dL2PsQ"
}

// Force-runs functions/analytics/reconcile_historical_tournament_events.xs on
// demand (bulk-rebuilds historical_tournament_event + _team from
// wrestler_match_history tournament-type rows for one season window).
query "admin/tournament-events/reconcile" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    timestamp season_start
    timestamp season_end
    text season_label
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    function.run reconcile_historical_tournament_events {
      input = {
        season_start: $input.season_start
        season_end  : $input.season_end
        season_label: $input.season_label
      }
    } as $result
  }

  response = $result
  guid = "Br4qZs7AnUw9PgVtCx1LfNh6KkAi8"
}

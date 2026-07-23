// Force-runs functions/analytics/reconcile_historical_dual_meets.xs on
// demand (bulk-rebuilds every historical dual_meet from wrestler_match_history
// dual-type rows). Useful after a historical-data backfill/correction lands.
query "admin/dual-meets/reconcile" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    function.run reconcile_historical_dual_meets {
      input = {}
    } as $result
  }

  response = $result
  guid = "g8rig1oQeZkC29fvRue8ioIEJKY"
}

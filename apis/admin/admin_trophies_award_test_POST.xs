// Scratch/manual test hook for award_tournament_trophies - lets it be
// exercised against an existing tournament's real rank data without going
// through the full open->locked->live->completed lifecycle. Delete once
// the trophy system is fully verified.
query "admin/trophies/award-test" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    int tournament_id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.get tournament {
      field_name = "id"
      field_value = $input.tournament_id
    } as $tournament

    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }

    function.run award_tournament_trophies {
      input = {tournament_id: $tournament.id, tournament_name: $tournament.name}
    } as $result
  }

  response = $result
  guid = "JssE6XVW0W_Pyf6npJHCDSjv1Lc"
}

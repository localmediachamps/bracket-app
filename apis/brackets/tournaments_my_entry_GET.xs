// Lightweight, read-only lookup of the current user's bracket entry for a
// tournament (id, status, is_submitted) - used to drive CTA text ("Make Your
// Picks" vs "Continue Picks" vs "View Your Submission") without creating an
// entry as a side effect. Deliberately a separate, simple query object rather
// than reusing tournaments/{slugOrId}'s personalization fields, which are
// disabled there due to a platform-level stale query-binding issue (see
// DEBUG_LOG.md) - this mirrors the same safe pattern already proven working
// in tournaments/{id}/entries (POST) and me/dashboard.
query "tournaments/{id}/my-entry" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    // Tournament id
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.query user_bracket {
      where = $db.user_bracket.user_id == $auth.id && $db.user_bracket.tournament_id == $input.id
      return = {type: "single"}
    } as $entry
  }

  response = $entry
  guid = "RYmkLbtfnT_2EDPiiVxedFInHsw"
}

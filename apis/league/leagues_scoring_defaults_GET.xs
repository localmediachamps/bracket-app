// Site-wide default scoring config (functions/utils/get_default_league_config.xs)
// - powers the Scoring Configuration settings card so it can show/prefill
// the real defaults a league falls back to for anything its own
// scoring_config doesn't override, instead of the commissioner staring at
// a blank form with no idea what "normal" looks like.
query "leagues/scoring/defaults" verb=GET {
  api_group = "league"
  auth = "user"

  input {
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    function.run get_default_league_config {
      input = {}
    } as $defaults
  }

  response = $defaults
  guid = "N4pXo7ZkTs2LcQwYb9HvJd5FgRe3"
}

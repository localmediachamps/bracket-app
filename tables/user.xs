table user {
  auth = true

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }

    text name filters=trim
    email? email filters=trim|lower
    password? password filters=min:8|minAlpha:1|minDigit:1
    bool is_admin?

    // url-safe handle; derive from email prefix when absent
    text username? filters=trim|lower

    text display_name? filters=trim
    text avatar_url?
    text bio?
    text favorite_school? filters=trim
    timestamp updated_at?

    // Opt out of appearing on public tournament-wide leaderboards entirely
    // (private group leaderboards are unaffected — those are visible only
    // to people the user already shares a group with)
    bool leaderboard_visible?=true

    // Which name to show when visible on the public leaderboard
    enum leaderboard_name_mode?="display_name" {
      values = ["display_name", "username"]
    }

    // Show a public list of this user's public bracket/pick'em submissions
    // (with points earned toward the master leaderboard) on their profile
    // page. Independent of leaderboard_visible, which only controls
    // appearing in leaderboard rankings, not what shows on the profile.
    bool show_public_submissions?=true

    // Show this user's personal wrestler rankings (the "my rankings" /
    // "show off your point of view" feature, stored in user_wrestler_ranking)
    // on their public profile. Independent of leaderboard_visible and
    // show_public_submissions - a separate opt-in for a separate section.
    bool show_public_rankings?=true

    // Email verification - signup sends a verify link immediately, but
    // being unverified doesn't block login/play, just gates whatever the
    // frontend chooses to gate later (e.g. notifications). Token+expiry
    // are cleared once consumed; never exposed via the API.
    bool email_verified?

    text? email_verify_token? {
      visibility = "private"
    }

    timestamp? email_verify_expires_at? {
      visibility = "private"
    }

    // Password reset - single-use token + expiry, cleared once consumed.
    // Never exposed via the API.
    text? password_reset_token? {
      visibility = "private"
    }

    timestamp? password_reset_expires_at? {
      visibility = "private"
    }

    // When the user accepted the Terms of Service + Privacy Policy - set
    // once at signup (mandatory checkbox), never cleared. Null would mean
    // an account somehow exists without ever accepting, which shouldn't be
    // possible via the app's own signup flow.
    timestamp? terms_accepted_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree|unique", field: [{name: "email", op: "asc"}]}
    {
      type : "btree|unique"
      field: [{name: "username", op: "asc"}]
    }
  ]
  guid = "9muXwZ5q7RHlyup9X6JrIFuSlLI"
}

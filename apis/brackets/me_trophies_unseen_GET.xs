// My own trophy_award rows with seen=false - drives the one-time reveal-
// ceremony modal on login/dashboard load.
query "me/trophies/unseen" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.query trophy_award {
      where = $db.trophy_award.recipient_user_id == $auth.id && $db.trophy_award.seen == false
      sort = {trophy_award.awarded_at: "asc"}
      return = {type: "list"}
    } as $unseen
  }

  response = {
    trophies: $unseen
  }
  guid = "P00FIGyl-vpbwQn5AY1xT_TMw7A"
}

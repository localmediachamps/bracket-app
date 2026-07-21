// Look up an existing Mat Savvy account by exact username, for the league
// invite flow ("invite specific accounts" - point 1 of the game design,
// no open/public join). Returns null if no match rather than 404, since
// "not found" is an expected, non-error result while someone is typing.
query "leagues/user-lookup" verb=GET {
  api_group = "league"
  auth = "user"

  input {
    text username filters=trim|lower
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.query user {
      where = $db.user.username == $input.username
      return = {type: "single"}
    } as $found_user

    var $result {
      value = null
    }

    conditional {
      if ($found_user != null) {
        var.update $result {
          value = {
            id          : $found_user.id
            username    : $found_user.username
            display_name: $found_user.display_name
            avatar_url  : $found_user.avatar_url
          }
        }
      }
    }
  }

  response = $result
  guid = "bZnUn9DeJsxO-N0Fh8_357M0iew"
}

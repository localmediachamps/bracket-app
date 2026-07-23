// Create a season-long fantasy league. Slug is unique within the season;
// invite_code is unique app-wide (kept for a future shareable-link flow, but
// the primary invite path is leagues_invite_POST - specific accounts only,
// no open/public join). Creator becomes owner with an active membership.
query leagues verb=POST {
  api_group = "league"
  auth = "user"

  input {
    // Season this league runs within
    int season_id

    // League name
    text name filters=trim|min:1

    // Optional description
    text? description? filters=trim

    // private | unlisted
    text privacy?=private filters=trim|lower

    // Optional member cap
    int? member_limit? filters=min:2

    // Optional league emoji
    text? avatar_emoji? filters=trim
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    precondition ($input.privacy == "private" || $input.privacy == "unlisted") {
      error_type = "inputerror"
      error = "privacy must be private or unlisted."
    }

    db.get season {
      field_name = "id"
      field_value = $input.season_id
    } as $season

    precondition ($season != null) {
      error_type = "notfound"
      error = "Season not found."
    }

    function.run slugify {
      input = {text: $input.name}
    } as $slug

    conditional {
      if ($slug == null || ($slug|strlen) == 0) {
        var.update $slug {
          value = "league"
        }
      }
    }

    db.query league {
      where = $db.league.season_id == $input.season_id && $db.league.slug == $slug
      return = {type: "exists"}
    } as $slug_taken

    var $slug_suffix {
      value = 1
    }

    var $final_slug {
      value = $slug
    }

    while ($slug_taken) {
      each {
        var.update $final_slug {
          value = $slug ~ "-" ~ $slug_suffix
        }

        math.add $slug_suffix {
          value = 1
        }

        db.query league {
          where = $db.league.season_id == $input.season_id && $db.league.slug == $final_slug
          return = {type: "exists"}
        } as $still_taken

        var.update $slug_taken {
          value = $still_taken
        }
      }
    }

    // Invite code with uniqueness retry (max 5 attempts)
    var $code {
      value = ""
    }

    var $tries {
      value = 0
    }

    while ($code == "" && $tries < 5) {
      each {
        function.run invite_code as $candidate

        db.has league {
          field_name = "invite_code"
          field_value = $candidate
        } as $code_taken

        conditional {
          if ($code_taken == false) {
            var.update $code {
              value = $candidate
            }
          }
        }

        math.add $tries {
          value = 1
        }
      }
    }

    precondition (($code|strlen) > 0) {
      error = "Could not allocate a unique invite code."
    }

    db.add league {
      data = {
        created_at    : now
        season_id     : $input.season_id
        owner_id      : $auth.id
        name          : $input.name
        slug          : $final_slug
        description   : $input.description
        privacy       : $input.privacy
        invite_code   : $code
        member_limit  : $input.member_limit
        member_count  : 1
        avatar_emoji  : $input.avatar_emoji|first_notempty:"🤼"
        status        : "forming"
      }
    } as $league

    db.add league_membership {
      data = {
        created_at: now
        league_id : $league.id
        user_id   : $auth.id
        role      : "owner"
        status    : "active"
        joined_at : now
      }
    } as $owner_membership
  }

  response = {league: $league, membership: $owner_membership}
  guid = "2C262LxaUQ9ld_cAOkV-hqdQXY0"
}

// Update league settings. Allowed for the league owner, an active
// commissioner-role member, or a site admin.
query "leagues/{id}" verb=PATCH {
  api_group = "league"
  auth = "user"

  input {
    // League id
    int id

    text? name? filters=trim|min:1
    text? description? filters=trim
    text? privacy? filters=trim|lower
    int? member_limit? filters=min:2
    text? avatar_emoji? filters=trim
    json? scoring_config?
    int? roster_starter_slots? filters=min:1
    text? roster_alternate_mode? filters=trim|lower
    int? roster_alternate_slots? filters=min:0
    int? roster_alternate_pool_size? filters=min:0
    json? draft_config?
    json? bowl_config?
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get league {
      field_name = "id"
      field_value = $input.id
    } as $league

    precondition ($league != null) {
      error_type = "notfound"
      error = "League not found."
    }

    conditional {
      if ($input.privacy != null) {
        precondition ($input.privacy == "private" || $input.privacy == "unlisted") {
          error_type = "inputerror"
          error = "privacy must be private or unlisted."
        }
      }
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id
      return = {type: "single"}
    } as $my_membership

    db.get user {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "is_admin"]
    } as $requester

    var $is_site_admin {
      value = ($requester != null && $requester.is_admin == true)
    }

    var $is_league_admin {
      value = ($my_membership != null && $my_membership.status == "active" && ($my_membership.role == "owner" || $my_membership.role == "commissioner"))
    }

    precondition ($league.owner_id == $auth.id || $is_league_admin || $is_site_admin) {
      error_type = "accessdenied"
      error = "Only the league owner or a commissioner can update this league."
    }

    var $changing_roster_shape {
      value = ($input.roster_starter_slots != null || $input.roster_alternate_mode != null || $input.roster_alternate_slots != null || $input.roster_alternate_pool_size != null)
    }

    precondition ($changing_roster_shape == false || $league.status == "forming") {
      error_type = "inputerror"
      error = "Roster shape is locked once the draft has started - changing it after picks exist would leave rosters inconsistent with what was actually drafted."
    }

    conditional {
      if ($input.roster_alternate_mode != null) {
        precondition ($input.roster_alternate_mode == "per_weight" || $input.roster_alternate_mode == "flat_pool") {
          error_type = "inputerror"
          error = "roster_alternate_mode must be per_weight or flat_pool."
        }
      }
    }

    var $payload {
      value = {updated_at: now}
    }

    conditional {
      if ($input.name != null) {
        var.update $payload {
          value = $payload|set:"name":$input.name
        }
      }
    }

    conditional {
      if ($input.description != null) {
        var.update $payload {
          value = $payload|set:"description":$input.description
        }
      }
    }

    conditional {
      if ($input.privacy != null) {
        var.update $payload {
          value = $payload|set:"privacy":$input.privacy
        }
      }
    }

    conditional {
      if ($input.member_limit != null) {
        var.update $payload {
          value = $payload|set:"member_limit":$input.member_limit
        }
      }
    }

    conditional {
      if ($input.avatar_emoji != null) {
        var.update $payload {
          value = $payload|set:"avatar_emoji":$input.avatar_emoji
        }
      }
    }

    conditional {
      if ($input.scoring_config != null) {
        var.update $payload {
          value = $payload|set:"scoring_config":$input.scoring_config
        }
      }
    }

    conditional {
      if ($input.roster_starter_slots != null) {
        var.update $payload {
          value = $payload|set:"roster_starter_slots":$input.roster_starter_slots
        }
      }
    }

    conditional {
      if ($input.roster_alternate_mode != null) {
        var.update $payload {
          value = $payload|set:"roster_alternate_mode":$input.roster_alternate_mode
        }
      }
    }

    conditional {
      if ($input.roster_alternate_slots != null) {
        var.update $payload {
          value = $payload|set:"roster_alternate_slots":$input.roster_alternate_slots
        }
      }
    }

    conditional {
      if ($input.roster_alternate_pool_size != null) {
        var.update $payload {
          value = $payload|set:"roster_alternate_pool_size":$input.roster_alternate_pool_size
        }
      }
    }

    conditional {
      if ($input.draft_config != null) {
        var.update $payload {
          value = $payload|set:"draft_config":$input.draft_config
        }
      }
    }

    conditional {
      if ($input.bowl_config != null) {
        var.update $payload {
          value = $payload|set:"bowl_config":$input.bowl_config
        }
      }
    }

    db.patch league {
      field_name = "id"
      field_value = $league.id
      data = $payload
    } as $updated_league
  }

  response = $updated_league
  guid = "PFkaph2XtMH38SNNJXNHYE8HlaE"
}

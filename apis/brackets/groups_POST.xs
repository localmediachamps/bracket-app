// Create a fantasy group: slug via slugify (uniqueness suffix within the
// tournament), invite code via invite_code with a uniqueness retry loop (max 5),
// creator becomes owner with an active owner membership and member_count = 1.
query groups verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    // Tournament the group belongs to
    int tournament_id
  
    // Group name
    text name filters=trim|min:1
  
    // Optional description
    text? description? filters=trim
  
    // public | unlisted | private
    text privacy?=private filters=trim|lower
  
    // Optional member cap
    int? member_limit? filters=min:2
  
    // Optional group emoji
    text? avatar_emoji? filters=trim
  }

  stack {
    precondition ($auth[""] != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    precondition ($input.privacy == "public" || $input.privacy == "unlisted" || $input.privacy == "private") {
      error_type = "inputerror"
      error = "privacy must be public, unlisted, or private."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $input.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    // Slug with uniqueness suffix within the tournament
    function.run slugify {
      input = {text: $input.name}
    } as $slug
  
    conditional {
      if ($slug == null || ($slug|strlen) == 0) {
        var.update $slug {
          value = "group"
        }
      }
    }
  
    db.query fantasy_group {
      where = $db.fantasy_group.tournament_id == $input.tournament_id && $db.fantasy_group.slug == $slug
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
      
        db.query fantasy_group {
          where = $db.fantasy_group.tournament_id == $input.tournament_id && $db.fantasy_group.slug == $final_slug
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
        db.has "" {
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
  
    db.add fantasy_group {
      data = {
        created_at   : now
        tournament_id: $input.tournament_id
        name         : $input.name
        slug         : $final_slug
        description  : $input.description
        owner_id     : $auth.id
        privacy      : $input.privacy
        invite_code  : $code
        member_limit : $input.member_limit
        member_count : 1
        avatar_emoji : $input.avatar_emoji|first_notempty:"🤼"
      }
    } as $group
  
    db.add group_membership {
      data = {
        created_at: now
        group_id  : $group.id
        user_id   : $auth.id
        role      : "owner"
        status    : "active"
        joined_at : now
      }
    } as $owner_membership
  }

  response = $group
}
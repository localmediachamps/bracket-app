query "brackets/tournament/{id}/weight/{weight}" verb=GET {
  api_group = "Brackets"
  description = "Get full bracket view for a weight class including matches, wrestlers, and the current user's picks."
  auth = "user"

  input {
    int id {
      description = "Tournament ID"
    }
    int weight {
      description = "Weight class in lbs (125, 133, 141, 149, 157, 165, 174, 184, 197, 285)"
    }
  }

  stack {
    db.query weight_class {
      where  = $db.weight_class.tournament_id == $input.id && $db.weight_class.weight == $input.weight
      return = {type: "single"}
    } as $weight_class

    precondition ($weight_class != null) {
      error_type = "notfound"
      error      = "Weight class not found."
    }

    db.query bracket_match {
      where  = $db.bracket_match.weight_class_id == $weight_class.id
      return = {type: "list"}
    } as $matches

    db.query wrestler {
      where  = $db.wrestler.weight_class_id == $weight_class.id
      return = {type: "list"}
    } as $wrestlers

    var $wrestlers_map {
      value = {}
    }

    foreach ($wrestlers) {
      each as $w {
        var.update $wrestlers_map {
          value = $wrestlers_map|set:$w.id:$w
        }
      }
    }

    var $user_bracket_id {
      value = null
    }

    var $picks_map {
      value = {}
    }

    db.query user_bracket {
      where  = $db.user_bracket.user_id == $auth.id && $db.user_bracket.tournament_id == $input.id
      return = {type: "single"}
    } as $user_bracket

    conditional {
      if ($user_bracket != null) {
        var.update $user_bracket_id {
          value = $user_bracket.id
        }

        db.query user_pick {
          where  = $db.user_pick.user_bracket_id == $user_bracket.id
          return = {type: "list"}
        } as $picks

        foreach ($picks) {
          each as $p {
            var.update $picks_map {
              value = $picks_map|set:$p.bracket_match_id:$p.picked_wrestler_id
            }
          }
        }
      }
    }
  }

  response = {
    weight_class   : $weight_class
    matches        : $matches
    wrestlers      : $wrestlers
    wrestlers_map  : $wrestlers_map
    picks_map      : $picks_map
    user_bracket_id: $user_bracket_id
  }
}

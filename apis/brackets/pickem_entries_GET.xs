// Pick'em entry detail: entry plus picks with weight class info, wrestler
// summaries, cost, points earned, and scoring breakdown. Viewable by the
// owner, any other logged-in user when the entry has opted into is_public,
// or a site admin. Requires login even for the is_public case - see
// entries_review_GET.xs's header for why $auth.id can't populate without
// auth="user", confirmed empirically 2026-07-22.
query "pickem-entries/{id}" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    // Pick'em entry id
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get pickem_entry {
      field_name = "id"
      field_value = $input.id
    } as $entry

    precondition ($entry != null) {
      error_type = "notfound"
      error = "Pick'em entry not found."
    }

    var $is_owner {
      value = $entry.user_id == $auth.id
    }

    var $can_view {
      value = $is_owner || $entry.is_public
    }

    conditional {
      if ($can_view == false && $auth.id != null) {
        db.get user {
          field_name = "id"
          field_value = $auth.id
          output = ["id", "is_admin"]
        } as $requester

        conditional {
          if ($requester != null && $requester.is_admin) {
            var.update $can_view {
              value = true
            }
          }
        }
      }
    }

    precondition ($can_view) {
      error_type = "accessdenied"
      error = "This entry is private."
    }

    db.get user {
      field_name = "id"
      field_value = $entry.user_id
      output = ["id", "username", "display_name", "avatar_url"]
    } as $entry_user

    db.query pickem_pick {
      where = $db.pickem_pick.pickem_entry_id == $entry.id
      return = {type: "list"}
    } as $picks
  
    var $pick_rows {
      value = []
    }
  
    foreach ($picks) {
      each as $p {
        db.get weight_class {
          field_name = "id"
          field_value = $p.weight_class_id
          output = ["id", "weight", "name"]
        } as $wc
      
        db.get wrestler {
          field_name = "id"
          field_value = $p.wrestler_id
          output = ["id", "name", "school", "seed"]
        } as $wrestler
      
        array.push $pick_rows {
          value = {
            id             : $p.id
            weight_class_id: $p.weight_class_id
            weight_class   : $wc
            wrestler       : $wrestler
            cost           : $p.cost
            points_earned  : $p.points_earned
            breakdown      : $p.breakdown
          }
        }
      }
    }
  }

  response = {entry: $entry, user: $entry_user, is_owner: $is_owner, picks: $pick_rows}
  guid = "I7YDiloGIlnubleReqivGap8l7o"
}
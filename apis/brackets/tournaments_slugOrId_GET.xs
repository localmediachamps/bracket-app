// Tournament overview by numeric id or slug: tournament record, weight classes,
// the requester's entries (when authenticated), leaderboard top 5, and group count.
query "tournaments/{slugOrId}" verb=GET {
  api_group = "brackets"

  input {
    // Tournament id (numeric) or slug
    text slugOrId filters=trim
  }

  stack {
    var $is_numeric {
      value = "/^d+$/"|regex_matches:$input.slugOrId
    }
  
    conditional {
      if ($is_numeric) {
        db.query tournament {
          where = $db.tournament.id == ($input.slugOrId|to_int)
          return = {type: "single"}
        } as $tournament
      }
    
      else {
        db.query tournament {
          where = $db.tournament.slug == ($input.slugOrId|to_lower)
          return = {type: "single"}
        } as $tournament
      }
    }
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    // Restricted statuses are never returned by this public endpoint — admins
    // use the admin endpoints instead (reading is_admin publicly is denied).
    precondition ($tournament.status != "draft" && $tournament.status != "importing" && $tournament.status != "needs_review" && $tournament.status != "cancelled") {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    db.query weight_class {
      where = $db.weight_class.tournament_id == $tournament.id
      sort = {weight_class.display_order: "asc"}
      return = {type: "list"}
    } as $weight_classes
  
    // Personalization when a valid token is present
    var $my_entry {
      value = null
    }
  
    var $my_pickem_entry {
      value = null
    }
  
    conditional {
      if ($auth.id != null) {
        db.query user_bracket {
          where = $db.user_bracket.user_id == $auth.id && $db.user_bracket.tournament_id == $tournament.id
          return = {type: "single"}
        } as $found_entry
      
        var.update $my_entry {
          value = $found_entry
        }
      
        db.query pickem_entry {
          where = $db.pickem_entry.user_id == $auth.id && $db.pickem_entry.tournament_id == $tournament.id
          return = {type: "single"}
        } as $found_pickem
      
        var.update $my_pickem_entry {
          value = $found_pickem
        }
      }
    }
  
    // Top 5 ranked bracket entries with user summaries
    db.query user_bracket {
      where = $db.user_bracket.tournament_id == $tournament.id && $db.user_bracket.rank != null
      sort = {user_bracket.rank: "asc"}
      return = {type: "list", paging: {page: 1, per_page: 5}}
    } as $top5_page
  
    var $leaderboard_top5 {
      value = []
    }
  
    foreach ($top5_page.items) {
      each as $row {
        db.get user {
          field_name = "id"
          field_value = $row.user_id
          output = ["id", "name", "username", "display_name", "avatar_url"]
        } as $row_user
      
        array.push $leaderboard_top5 {
          value = $row|set:"user":$row_user
        }
      }
    }
  
    db.query fantasy_group {
      where = $db.fantasy_group.tournament_id == $tournament.id
      return = {type: "count"}
    } as $group_count
  }

  response = {
    tournament      : $tournament
    weight_classes  : $weight_classes
    my_entry        : $my_entry
    my_pickem_entry : $my_pickem_entry
    leaderboard_top5: $leaderboard_top5
    group_count     : $group_count
  }
}
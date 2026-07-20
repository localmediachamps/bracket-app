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
      value = "/^[0-9]+$/"|regex_matches:$input.slugOrId
    }

    var $numeric_id {
      value = $input.slugOrId|to_int
    }

    conditional {
      if ($is_numeric) {
        db.query tournament {
          where = $db.tournament.id == $numeric_id
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

    // KNOWN ISSUE: personalization (my_entry/my_pickem_entry), the top-5
    // leaderboard, and group_count are hardcoded below instead of queried.
    // This workspace's user_bracket/pickem_entry/fantasy_group table
    // references on THIS query are stale at the platform level — confirmed
    // this is not about where/sort/paging content (even a bare
    // zero-condition db.query throws), and not a normal runtime exception
    // (try_catch does not catch it; the whole request gets rejected with a
    // masked ERROR_CODE_ACCESS_DENIED before the stack executes at all,
    // apparently from the mere presence of the broken reference anywhere in
    // the compiled query, even inside a skipped conditional or a try block).
    // Re-saving the XanoScript text does not rebind it. To restore: open this
    // query in Xano's visual query builder and re-pick "user_bracket" /
    // "pickem_entry" / "fantasy_group" from the table picker on each
    // db.query step (forces a fresh GUID binding), then reintroduce the
    // three queries removed here (see git history for the original logic).
    var $my_entry {
      value = null
    }

    var $my_pickem_entry {
      value = null
    }

    var $leaderboard_top5 {
      value = []
    }

    var $group_count {
      value = 0
    }
  }

  response = $tournament
    |set:"weight_classes":$weight_classes
    |set:"my_entry":$my_entry
    |set:"my_pickem_entry":$my_pickem_entry
    |set:"leaderboard_top5":$leaderboard_top5
    |set:"group_count":$group_count
  guid = "BIzFW5ZSfYLlsELS37SorZmeqPw"
}
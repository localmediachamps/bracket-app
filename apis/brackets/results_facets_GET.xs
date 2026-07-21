// Distinct wrestler names + event names for the results explorer's cascading
// filters - narrowed by whichever of school/weight_class are currently
// selected, so both lists only ever show values that actually fit the other
// active filters. Wrestler names are pulled from whichever SIDE of the match
// actually belongs to the selected school (winner_school or loser_school),
// not both sides indiscriminately - otherwise an opponent from a different
// school would incorrectly show up as a selectable "wrestler" option.
query "results/facets" verb=GET {
  api_group = "brackets"

  input {
    text? school? filters=trim|max:100
    text? weight_class?
  }

  stack {
    var $school_lower {
      value = $input.school|to_lower
    }

    db.query wrestler_match_history {
      where = (($db.wrestler_match_history.winner_school_raw|to_lower) ==? $school_lower) && ($db.wrestler_match_history.weight_class ==? $input.weight_class)
      return = {
        type  : "list"
        paging: {page: 1, per_page: 2000}
      }
    } as $winner_side

    db.query wrestler_match_history {
      where = (($db.wrestler_match_history.loser_school_raw|to_lower) ==? $school_lower) && ($db.wrestler_match_history.weight_class ==? $input.weight_class)
      return = {
        type  : "list"
        paging: {page: 1, per_page: 2000}
      }
    } as $loser_side

    var $wrestler_names_raw {
      value = ($winner_side.items|map:$$.winner_name_raw)|merge:($loser_side.items|map:$$.loser_name_raw)
    }

    var $wrestlers {
      value = ($wrestler_names_raw|filter_empty_text)|unique|sort
    }

    var $event_names_raw {
      value = ($winner_side.items|map:$$.event_name)|merge:($loser_side.items|map:$$.event_name)
    }

    var $event_names {
      value = ($event_names_raw|filter_empty_text)|unique|sort
    }
  }

  response = {
    wrestlers  : $wrestlers
    event_names: $event_names
  }
  guid = "gHQaiDOYO7w7lUrKpFDxTsbhWQk"
}

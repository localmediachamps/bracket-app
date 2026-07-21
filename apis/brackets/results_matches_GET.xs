// Search/browse historical wrestler match results (wrestler_match_history).
// All filters are optional and compose together (AND) - browsing with no
// filters at all returns the full paginated dataset, newest first. `q` is a
// master search across wrestler name, school, and event name/series - not
// wrestler-name-only. Raw text search only - no canonical_wrestler linkage yet.
query "results/matches" verb=GET {
  api_group = "brackets"

  input {
    text? q? filters=trim|max:100
    text? school? filters=trim|max:100
    text? wrestler? filters=trim|max:100
    text? event_name? filters=trim|max:150
    text? weight_class?
    timestamp? start_date?
    timestamp? end_date?

    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    var $q_lower {
      value = $input.q|to_lower
    }

    var $school_lower {
      value = $input.school|to_lower
    }

    var $wrestler_lower {
      value = $input.wrestler|to_lower
    }

    var $event_lower {
      value = $input.event_name|to_lower
    }

    db.query wrestler_match_history {
      where = ($input.q == null || (($db.wrestler_match_history.winner_name_raw|to_lower) includes $q_lower) || (($db.wrestler_match_history.loser_name_raw|to_lower) includes $q_lower) || (($db.wrestler_match_history.winner_school_raw|to_lower) includes $q_lower) || (($db.wrestler_match_history.loser_school_raw|to_lower) includes $q_lower) || (($db.wrestler_match_history.event_name|to_lower) includes $q_lower) || (($db.wrestler_match_history.event_series_name|to_lower) includes $q_lower)) && ($input.school == null || (($db.wrestler_match_history.winner_school_raw|to_lower) == $school_lower) || (($db.wrestler_match_history.loser_school_raw|to_lower) == $school_lower)) && ($input.wrestler == null || (($db.wrestler_match_history.winner_name_raw|to_lower) == $wrestler_lower) || (($db.wrestler_match_history.loser_name_raw|to_lower) == $wrestler_lower)) && ($input.event_name == null || (($db.wrestler_match_history.event_name|to_lower) == $event_lower)) && ($db.wrestler_match_history.weight_class ==? $input.weight_class) && ($db.wrestler_match_history.occurred_at >=? $input.start_date) && ($db.wrestler_match_history.occurred_at <=? $input.end_date)
      sort = {wrestler_match_history.occurred_at: "desc"}
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $page
  }

  response = {
    items: $page.items
    total: $page.itemsTotal
    page : $input.page
    per  : $input.per
  }
  guid = "5HLk8d3llJ8upX36lYIDE9AF2Qw"
}

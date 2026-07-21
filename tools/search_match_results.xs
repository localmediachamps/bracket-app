// AI-facing tool wrapping the same wrestler_match_history search logic as
// the public /results/matches API - lets an agent answer questions about
// real historical wrestling match results (who beat whom, records at a
// school/weight, event history, etc.). Read-only. First use case for the
// results-analyst agent scaffolding - more tools (career records,
// head-to-head, canonical_wrestler profiles) come later once identity
// resolution exists.
tool "search_match_results" {
  description = "Searches historical wrestling match results (wrestler_match_history table)."
  instructions = "Use this to answer any question about real match results: who wrestled whom, who won, records at a given school or weight class, matches at a specific event, or matches in a date/season range. All filters are optional and combine together (AND) - omit filters you don't need. If the question names a wrestler, school, or event but you're unsure of the exact spelling, try a broader search with just `query` first, then narrow with the more specific filters once you see real values in the results. Results are capped at 200 rows per call - if a query might match more than that, narrow the filters (e.g. add a weight_class or date range) rather than assuming you have the complete picture from a truncated result."

  input {
    text? query? filters=trim|max:100 {
      description = "Free-text search across wrestler name, school, and event name/series. Use for a broad first pass."
    }
    text? school? filters=trim|max:100 {
      description = "Exact school name to filter to matches involving this team (either side), e.g. 'Ohio State'."
    }
    text? wrestler? filters=trim|max:100 {
      description = "Exact wrestler name to filter to matches involving this specific person (either side)."
    }
    text? event_name? filters=trim|max:150 {
      description = "Exact event name to filter to one specific event/tournament, e.g. '2026 NCAA Division I Championships'."
    }
    text? weight_class? {
      description = "Weight class in pounds as text, e.g. '133' or '285'."
    }
    timestamp? start_date? {
      description = "Only include matches on/after this date."
    }
    timestamp? end_date? {
      description = "Only include matches on/before this date."
    }
    int limit?=50 filters=min:1|max:200 {
      description = "Max rows to return, default 50, hard cap 200."
    }
  }

  stack {
    var $q_lower {
      value = $input.query|to_lower
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
      where = ($input.query == null || (($db.wrestler_match_history.winner_name_raw|to_lower) includes $q_lower) || (($db.wrestler_match_history.loser_name_raw|to_lower) includes $q_lower) || (($db.wrestler_match_history.winner_school_raw|to_lower) includes $q_lower) || (($db.wrestler_match_history.loser_school_raw|to_lower) includes $q_lower) || (($db.wrestler_match_history.event_name|to_lower) includes $q_lower) || (($db.wrestler_match_history.event_series_name|to_lower) includes $q_lower)) && ($input.school == null || (($db.wrestler_match_history.winner_school_raw|to_lower) == $school_lower) || (($db.wrestler_match_history.loser_school_raw|to_lower) == $school_lower)) && ($input.wrestler == null || (($db.wrestler_match_history.winner_name_raw|to_lower) == $wrestler_lower) || (($db.wrestler_match_history.loser_name_raw|to_lower) == $wrestler_lower)) && ($input.event_name == null || (($db.wrestler_match_history.event_name|to_lower) == $event_lower)) && ($db.wrestler_match_history.weight_class ==? $input.weight_class) && ($db.wrestler_match_history.occurred_at >=? $input.start_date) && ($db.wrestler_match_history.occurred_at <=? $input.end_date)
      sort = {wrestler_match_history.occurred_at: "desc"}
      return = {
        type  : "list"
        paging: {page: 1, per_page: $input.limit, totals: true}
      }
    } as $page
  }

  response = {
    total_matching   : $page.itemsTotal
    returned         : $page.items|count
    truncated        : ($page.itemsTotal) > ($page.items|count)
    results          : $page.items|map:{
      date          : $$.occurred_at
      weight_class  : $$.weight_class
      winner        : $$.winner_name_raw
      winner_school : $$.winner_school_raw
      loser         : $$.loser_name_raw
      loser_school  : $$.loser_school_raw
      victory_type  : $$.victory_type
      round         : $$.round_label
      event_name    : $$.event_name
      event_series  : $$.event_series_name
    }
  }
  guid = "-JAinRqVQaoQ4B9WqoQBZECWDxA"
}

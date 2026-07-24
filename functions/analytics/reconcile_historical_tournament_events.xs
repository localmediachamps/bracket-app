// Groups every event_type=="tournament" row in wrestler_match_history within
// a date window by event_id_external into real historical_tournament_event +
// historical_tournament_event_team records - the tournament-side counterpart
// to reconcile_historical_dual_meets.xs, same streaming-by-sorted-group
// pattern (confirmed cheap; building one big {event_id: [rows]} map instead
// is confirmed NOT cheap, see that function's header comment). Idempotent
// via event_id_external (db.add_or_edit + wipe-and-rebuild each run).
function reconcile_historical_tournament_events {
  input {
    timestamp season_start
    timestamp season_end
    text season_label
  }

  stack {
    db.query wrestler_match_history {
      where = $db.wrestler_match_history.event_type == "tournament" && $db.wrestler_match_history.occurred_at >= $input.season_start && $db.wrestler_match_history.occurred_at <= $input.season_end
      sort = {wrestler_match_history.event_id_external: "asc"}
      return = {
        type  : "list"
        paging: {page: 1, per_page: 30000, totals: true}
      }
    } as $page_result

    var $all_rows { value = $page_result.items }
    var $total_rows { value = $all_rows|count }

    db.query canonical_team {
      return = {type: "list"}
    } as $teams

    var $team_id_by_name { value = {} }

    foreach ($teams) {
      each as $t {
        var.update $team_id_by_name { value = $team_id_by_name|set:$t.name:$t.id }
      }
    }

    // Built ONCE for the whole run, not per group/wrestler - every wrestler
    // tagged is_starter for this season, keyed by wrestler id (text).
    db.query canonical_wrestler_team {
      where = $db.canonical_wrestler_team.season_label == $input.season_label && $db.canonical_wrestler_team.is_starter == true
      return = {type: "list", paging: {page: 1, per_page: 50000}}
    } as $starter_rows

    var $starter_wrestler_ids { value = {} }

    foreach ($starter_rows.items) {
      each as $sr {
        var.update $starter_wrestler_ids { value = $starter_wrestler_ids|set:($sr.canonical_wrestler_id|to_text):true }
      }
    }

    var $current_ek { value = null }
    var $current_group { value = [] }

    var $events_written { value = 0 }
    var $groups_seen { value = 0 }
    var $idx { value = 0 }

    foreach ($all_rows) {
      each as $r {
        math.add $idx { value = 1 }

        var $r_ek { value = $r.event_id_external }
        var $is_new_group { value = $current_ek != null && $r_ek != $current_ek }

        conditional {
          if ($is_new_group) {
            function.run process_historical_tournament_event_group {
              input = {
                event_id            : $current_ek
                rows                 : $current_group
                team_id_by_name      : $team_id_by_name
                starter_wrestler_ids : $starter_wrestler_ids
                season_label         : $input.season_label
              }
            } as $group_result

            math.add $groups_seen { value = 1 }
            math.add $events_written { value = 1 }

            var.update $current_group { value = [] }
          }
        }

        conditional {
          if ($r_ek != null && ($r_ek|strlen) > 0) {
            array.push $current_group { value = $r }
            var.update $current_ek { value = $r_ek }
          }
        }

        conditional {
          if ($idx == $total_rows && ($current_group|count) > 0) {
            function.run process_historical_tournament_event_group {
              input = {
                event_id            : $current_ek
                rows                 : $current_group
                team_id_by_name      : $team_id_by_name
                starter_wrestler_ids : $starter_wrestler_ids
                season_label         : $input.season_label
              }
            } as $final_group_result

            math.add $groups_seen { value = 1 }
            math.add $events_written { value = 1 }
          }
        }
      }
    }
  }

  response = {
    tournament_rows_scanned: $total_rows
    groups_seen            : $groups_seen
    events_written         : $events_written
  }
  guid = "Aq3pYr6ZmTv8OfUsBw9KeMg5JjZh7"
}

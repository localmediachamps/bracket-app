// Groups every event_type=="dual" row in wrestler_match_history (one row per
// individual bout) by event_id_external into real dual_meet +
// dual_meet_weight_slot records - the reconciliation that turns "vs. Bucknell"
// (one team's own schedule text, no opponent-of-the-opponent framing, no
// score) into a real two-team record with a final NCAA dual score, browsable
// the same way tournament results are. Idempotent via source_match_key =
// event_id_external (db.add_or_edit + wipe-and-rebuild the weight slots each
// run), so re-running after a historical-data backfill correction is safe.
//
// Home/away is NOT true home-venue - that isn't recoverable from this raw
// data. See process_historical_dual_meet_group.xs for the "vs. {opponent}"
// derivation and the per-group processing this delegates to.
//
// CONFIRMED PERFORMANCE BUG (2026-07-23): the original version of this
// function queried rows sorted by id and built one big {event_id: [rows]}
// map via repeated foreach + array.push + |set:. That alone (with NO other
// logic) took over 90 seconds and never finished for real - confirmed by an
// isolated scratch-endpoint test. Building a map whose VALUES are growing
// arrays of full row objects, one |set: per source row (~19k times), is far
// more expensive than compute_stat_leaders_for_season.xs's per-row map
// bumps (those values are single integers, not growing arrays - still
// O(rows x keys), but a much smaller constant). Fix: query sorted by
// event_id_external instead (so one event's rows land contiguously) and
// stream through in a single pass, accumulating only ONE small
// current-group array at a time (never a giant map), calling
// process_historical_dual_meet_group via function.run once per GROUP
// (~2,000 calls) rather than once per row (~19k calls) or building any
// structure that scales with total row count.
function reconcile_historical_dual_meets {
  input {
    // Debug/perf-testing aid: only process the first N event groups.
    // Omitted (null) processes everything.
    int? limit_groups?
  }

  stack {
    db.query wrestler_match_history {
      where = $db.wrestler_match_history.event_type == "dual"
      sort = {wrestler_match_history.event_id_external: "asc"}
      return = {
        type  : "list"
        paging: {page: 1, per_page: 30000, totals: true}
      }
    } as $page_result

    var $all_rows { value = $page_result.items }
    var $total_rows { value = $all_rows|count }

    // Small, cheap table - fetch all once for in-memory name->id lookup.
    db.query canonical_team {
      return = {type: "list"}
    } as $teams

    var $team_id_by_name { value = {} }

    foreach ($teams) {
      each as $t {
        var.update $team_id_by_name { value = $team_id_by_name|set:$t.name:$t.id }
      }
    }

    var $current_ek { value = null }
    var $current_group { value = [] }

    var $created_count { value = 0 }
    var $skipped_count { value = 0 }
    var $slots_written { value = 0 }
    var $groups_seen { value = 0 }
    var $idx { value = 0 }
    var $stop { value = false }

    foreach ($all_rows) {
      each as $r {
        math.add $idx { value = 1 }

        conditional {
          if ($stop == false) {
            var $r_ek { value = $r.event_id_external }
            var $is_new_group { value = $current_ek != null && $r_ek != $current_ek }

            conditional {
              if ($is_new_group) {
                var $under_limit { value = $limit_groups == null || $groups_seen < $limit_groups }

                conditional {
                  if ($under_limit) {
                    function.run process_historical_dual_meet_group {
                      input = {event_id: $current_ek, rows: $current_group, team_id_by_name: $team_id_by_name}
                    } as $group_result

                    math.add $groups_seen { value = 1 }

                    conditional {
                      if ($group_result.created) {
                        math.add $created_count { value = 1 }
                        math.add $slots_written { value = $group_result.slots_written }
                      }
                      else {
                        math.add $skipped_count { value = 1 }
                      }
                    }
                  }
                  else {
                    var.update $stop { value = true }
                  }
                }

                var.update $current_group { value = [] }
              }
            }

            conditional {
              if ($stop == false && $r_ek != null && ($r_ek|strlen) > 0) {
                array.push $current_group { value = $r }
                var.update $current_ek { value = $r_ek }
              }
            }

            conditional {
              if ($stop == false && $idx == $total_rows && ($current_group|count) > 0) {
                var $under_limit_final { value = $limit_groups == null || $groups_seen < $limit_groups }

                conditional {
                  if ($under_limit_final) {
                    function.run process_historical_dual_meet_group {
                      input = {event_id: $current_ek, rows: $current_group, team_id_by_name: $team_id_by_name}
                    } as $final_group_result

                    math.add $groups_seen { value = 1 }

                    conditional {
                      if ($final_group_result.created) {
                        math.add $created_count { value = 1 }
                        math.add $slots_written { value = $final_group_result.slots_written }
                      }
                      else {
                        math.add $skipped_count { value = 1 }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  response = {
    dual_rows_scanned: $total_rows
    groups_seen      : $groups_seen
    reconciled       : $created_count
    skipped          : $skipped_count
    slots_written    : $slots_written
  }
  guid = "1jXMmcYGL-cSBOHGBg6H1-bK44c"
}

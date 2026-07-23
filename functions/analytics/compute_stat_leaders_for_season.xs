// Scans wrestler_match_history for one season window and rebuilds that
// season's row in season_stat_leaders (most wins/pins/tech-falls, fastest
// falls, highest-scoring matches). Extracted out of
// tasks/compute_season_stat_leaders.xs so it can also be run directly
// (`xano function run compute_stat_leaders_for_season -d ...`) to test or
// force-refresh a single season without waiting for the daily schedule.
//
// One unpaged db.query for the whole season (confirmed a single season is
// ~24-25k rows, and Xano returns all of them fine in one query with a
// generous per_page - no pagination loop needed).
//
// IMPORTANT: victory-type classification and the win/pin/tech-fall counter
// bumps are inlined directly in the per-row loop below rather than calling
// normalize_victory_type/bump_season_map via function.run per row. Confirmed
// via isolated testing (2026-07-23) that calling those (otherwise correct)
// helper functions ~4x per row across ~25k rows made a single season take
// several minutes (still hadn't finished after 2+ min before being killed) -
// function.run has real per-call overhead that adds up at this scale, even
// though it works fine at the scale it's used everywhere else in this
// codebase (dozens of matches, not tens of thousands). The inlined
// classification only needs to distinguish fall vs tech_fall (not the full
// medical/injury/disqualification/forfeit cascade normalize_victory_type
// handles) - safe here since none of those raw strings contain "fall"/
// "pin"/"tech", so there's no ambiguity to resolve for this narrower need.
function compute_stat_leaders_for_season {
  input {
    text season_label filters=trim
    int season_start
    int season_end
  }

  stack {
    db.query wrestler_match_history {
      where = $db.wrestler_match_history.occurred_at >= $input.season_start && $db.wrestler_match_history.occurred_at <= $input.season_end
      sort = {wrestler_match_history.id: "asc"}
      return = {
        type  : "list"
        paging: {page: 1, per_page: 50000, totals: true}
      }
    } as $page_result

    var $all_matches { value = $page_result.items }

    var $wins_map { value = {} }
    var $pins_map { value = {} }
    var $techfall_map { value = {} }
    var $fastest_falls { value = [] }
    var $highest_scoring { value = [] }
    var $matches_considered { value = 0 }

    foreach ($all_matches) {
      each as $m {
        math.add $matches_considered { value = 1 }

        var $vt_lower { value = "" }

        conditional {
          if ($m.victory_type != null) {
            var.update $vt_lower { value = $m.victory_type|to_lower|trim }
          }
        }

        var $has_tech { value = $vt_lower|contains:"tech" }
        var $has_fall { value = $vt_lower|contains:"fall" }
        var $has_pin { value = $vt_lower|contains:"pin" }
        var $is_fall_word { value = $has_fall || $has_pin }

        var $vtype { value = "other" }

        conditional {
          if ($has_tech) {
            var.update $vtype { value = "tech_fall" }
          }
          elseif ($is_fall_word) {
            var.update $vtype { value = "fall" }
          }
        }

        conditional {
          if ($m.winner_canonical_wrestler_id != null) {
            var $wid { value = ($m.winner_canonical_wrestler_id|to_text) }

            var $prev_wins { value = 0 }
            conditional {
              if ($wins_map|has:$wid) {
                var.update $prev_wins { value = $wins_map[$wid] }
              }
            }
            var.update $wins_map { value = $wins_map|set:$wid:($prev_wins + 1) }

            conditional {
              if ($vtype == "fall") {
                var $prev_pins { value = 0 }
                conditional {
                  if ($pins_map|has:$wid) {
                    var.update $prev_pins { value = $pins_map[$wid] }
                  }
                }
                var.update $pins_map { value = $pins_map|set:$wid:($prev_pins + 1) }
              }
              elseif ($vtype == "tech_fall") {
                var $prev_tf { value = 0 }
                conditional {
                  if ($techfall_map|has:$wid) {
                    var.update $prev_tf { value = $techfall_map[$wid] }
                  }
                }
                var.update $techfall_map { value = $techfall_map|set:$wid:($prev_tf + 1) }
              }
            }
          }
        }

        conditional {
          if ($vtype == "fall" && $m.time_seconds != null) {
            array.push $fastest_falls {
              value = {
                match_id     : $m.id
                wrestler_name: $m.winner_name_raw
                opponent_name: $m.loser_name_raw
                weight_class : $m.weight_class
                time_seconds : $m.time_seconds
                event_name   : $m.event_name
                occurred_at  : $m.occurred_at
              }
            }
          }
        }

        conditional {
          if ($m.score != null) {
            var $score_parts { value = ($m.score|split:"-") }
            var $score_total { value = null }

            conditional {
              if (($score_parts|count) == 2) {
                var $w_score { value = ($score_parts|get:0:"0")|to_int }
                var $l_score { value = ($score_parts|get:1:"0")|to_int }
                var.update $score_total { value = `$w_score + $l_score` }
              }
            }

            conditional {
              if ($score_total != null) {
                array.push $highest_scoring {
                  value = {
                    match_id    : $m.id
                    winner_name : $m.winner_name_raw
                    loser_name  : $m.loser_name_raw
                    weight_class: $m.weight_class
                    score       : $m.score
                    total_points: $score_total
                    event_name  : $m.event_name
                    occurred_at : $m.occurred_at
                  }
                }
              }
            }
          }
        }
      }
    }

    var $fastest_falls_top {
      value = ($fastest_falls|sort:"time_seconds":"number")|slice:0:5
    }

    var $highest_scoring_top {
      value = (($highest_scoring|sort:"total_points":"number")|reverse)|slice:0:5
    }

    function.run build_stat_leader_list {
      input = {counts_map: $wins_map, limit: 10}
    } as $most_wins

    function.run build_stat_leader_list {
      input = {counts_map: $pins_map, limit: 10}
    } as $most_pins

    function.run build_stat_leader_list {
      input = {counts_map: $techfall_map, limit: 10}
    } as $most_tech_falls

    db.add_or_edit season_stat_leaders {
      field_name = "season_label"
      field_value = $input.season_label
      data = {
        season_label            : $input.season_label
        most_wins                : $most_wins
        most_pins                : $most_pins
        most_tech_falls          : $most_tech_falls
        fastest_falls            : $fastest_falls_top
        highest_scoring_matches  : $highest_scoring_top
        matches_considered       : $matches_considered
        computed_at              : now
      }
    } as $saved_row
  }

  response = {
    season_label      : $input.season_label
    matches_considered: $matches_considered
    wins_leaders_count: ($most_wins|count)
    pins_leaders_count: ($most_pins|count)
  }
  guid = "YCrjfdFzVBikZm4lqByFOl8Yd4c"
}

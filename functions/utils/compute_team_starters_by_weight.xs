// Given a real college team + season, returns the same "starter" heuristic
// used on the team profile page (results/teams/{id}) as a plain map:
// weight_class (text) -> {wrestler_id, display_name}. Whoever has the most
// matches at that weight this season wins, unless overridden per-row via
// canonical_wrestler_team.is_starter_override (true forces them in, false
// excludes them from the heuristic entirely). Shared so the lineup-setting
// "projected opponent" feature doesn't duplicate this logic.
function compute_team_starters_by_weight {
  input {
    int team_id
    text season_label
  }

  stack {
    var $season_bounds {
      value = {
        "2022-23": {start: 1659312000000, end: 1690847999000}
        "2023-24": {start: 1690848000000, end: 1722470399000}
        "2024-25": {start: 1722470400000, end: 1754006399000}
        "2025-26": {start: 1754006400000, end: 1785628799000}
      }
    }

    var $bounds {
      value = $season_bounds|get:$input.season_label:null
    }

    db.query canonical_wrestler_team {
      where = $db.canonical_wrestler_team.canonical_team_id == $input.team_id && $db.canonical_wrestler_team.season_label == $input.season_label
      return = {type: "list"}
    } as $links

    var $starter_best_id { value = {} }
    var $starter_best_score { value = {} }
    var $starter_best_name { value = {} }
    var $starter_forced_id { value = {} }
    var $starter_forced_name { value = {} }

    foreach ($links) {
      each as $l {
        db.get canonical_wrestler {
          field_name = "id"
          field_value = $l.canonical_wrestler_id
        } as $w

        conditional {
          if ($w != null) {
            var $weight_class { value = null }
            var $wins { value = 0 }
            var $losses { value = 0 }

            conditional {
              if ($bounds != null) {
                db.query wrestler_match_history {
                  where = (($db.wrestler_match_history.winner_canonical_wrestler_id == $l.canonical_wrestler_id) || ($db.wrestler_match_history.loser_canonical_wrestler_id == $l.canonical_wrestler_id)) && ($db.wrestler_match_history.occurred_at >= $bounds.start) && ($db.wrestler_match_history.occurred_at <= $bounds.end)
                  return = {type: "list"}
                } as $season_matches

                foreach ($season_matches) {
                  each as $sm {
                    conditional {
                      if ($weight_class == null) {
                        var.update $weight_class { value = $sm.weight_class }
                      }
                    }

                    conditional {
                      if ($sm.winner_canonical_wrestler_id == $l.canonical_wrestler_id) {
                        math.add $wins { value = 1 }
                      }
                      else {
                        math.add $losses { value = 1 }
                      }
                    }
                  }
                }
              }
            }

            conditional {
              if ($weight_class == null) {
                var.update $weight_class { value = $w.current_weight_class }
              }
            }

            conditional {
              if ($weight_class != null) {
                var $wkey { value = ($weight_class|to_text) }
                var $score { value = ($wins + $losses) }

                conditional {
                  if ($l.is_starter_override != null && $l.is_starter_override == true) {
                    var.update $starter_forced_id { value = $starter_forced_id|set:$wkey:$w.id }
                    var.update $starter_forced_name { value = $starter_forced_name|set:$wkey:$w.display_name }
                  }
                }

                // Excluded rows (explicitly benched via override=false) never
                // win the best-record heuristic, even with the top score.
                var $excluded { value = false }

                conditional {
                  if ($l.is_starter_override != null && $l.is_starter_override == false) {
                    var.update $excluded { value = true }
                  }
                }

                conditional {
                  if ($excluded == false) {
                    var $prev { value = $starter_best_score|get:$wkey:null }

                    conditional {
                      if ($prev == null) {
                        var.update $starter_best_score { value = $starter_best_score|set:$wkey:$score }
                        var.update $starter_best_id { value = $starter_best_id|set:$wkey:$w.id }
                        var.update $starter_best_name { value = $starter_best_name|set:$wkey:$w.display_name }
                      }
                      elseif ($score > $prev) {
                        var.update $starter_best_score { value = $starter_best_score|set:$wkey:$score }
                        var.update $starter_best_id { value = $starter_best_id|set:$wkey:$w.id }
                        var.update $starter_best_name { value = $starter_best_name|set:$wkey:$w.display_name }
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

    var $result { value = {} }
    var $weight_keys { value = ($starter_best_score|keys) }

    foreach ($weight_keys) {
      each as $wk {
        conditional {
          if ($starter_forced_id|has:$wk) {
            var.update $result {
              value = $result|set:$wk:{wrestler_id: ($starter_forced_id|get:$wk:null), display_name: ($starter_forced_name|get:$wk:null)}
            }
          }
          else {
            var.update $result {
              value = $result|set:$wk:{wrestler_id: ($starter_best_id|get:$wk:null), display_name: ($starter_best_name|get:$wk:null)}
            }
          }
        }
      }
    }
  }

  response = $result
  guid = "V3nRq8ZkYs2LtWpXo6HcJd4FbGe9"
}

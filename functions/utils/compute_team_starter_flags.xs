// Same starter heuristic as compute_team_starters_by_weight.xs (most matches
// this season at a weight wins, unless is_starter_override forces it), but
// returns a flag for EVERY canonical_wrestler_team row on the team/season
// instead of just the weight-by-weight winner - used to backfill the stored
// canonical_wrestler_team.is_starter field (see tasks/compute_starter_tags.xs)
// so bulk list views don't need to recompute this live per team.
function compute_team_starter_flags {
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

    var $rows {
      value = []
    }

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

            array.push $rows {
              value = {
                row_id: $l.id
                wrestler_id: $l.canonical_wrestler_id
                weight_class: $weight_class
                score: ($wins + $losses)
                override: $l.is_starter_override
              }
            }
          }
        }
      }
    }

    var $best_score { value = {} }
    var $best_wrestler { value = {} }
    var $forced_wrestler { value = {} }

    foreach ($rows) {
      each as $row {
        conditional {
          if ($row.weight_class != null) {
            var $wkey { value = ($row.weight_class|to_text) }

            conditional {
              if ($row.override != null && $row.override == true) {
                var.update $forced_wrestler { value = $forced_wrestler|set:$wkey:$row.wrestler_id }
              }
            }

            var $excluded { value = false }

            conditional {
              if ($row.override != null && $row.override == false) {
                var.update $excluded { value = true }
              }
            }

            conditional {
              if ($excluded == false) {
                var $prev { value = $best_score|get:$wkey:null }

                conditional {
                  if ($prev == null) {
                    var.update $best_score { value = $best_score|set:$wkey:$row.score }
                    var.update $best_wrestler { value = $best_wrestler|set:$wkey:$row.wrestler_id }
                  }
                  elseif ($row.score > $prev) {
                    var.update $best_score { value = $best_score|set:$wkey:$row.score }
                    var.update $best_wrestler { value = $best_wrestler|set:$wkey:$row.wrestler_id }
                  }
                }
              }
            }
          }
        }
      }
    }

    var $flags { value = [] }

    foreach ($rows) {
      each as $row2 {
        var $is_starter { value = false }

        conditional {
          if ($row2.weight_class != null) {
            var $wkey2 { value = ($row2.weight_class|to_text) }

            conditional {
              if ($forced_wrestler|has:$wkey2) {
                var $forced_id { value = $forced_wrestler|get:$wkey2:null }

                conditional {
                  if ($forced_id != null) {
                    var.update $is_starter { value = (($row2.wrestler_id|to_text) == ($forced_id|to_text)) }
                  }
                }
              }
              elseif ($row2.override != null && $row2.override == false) {
                var.update $is_starter { value = false }
              }
              else {
                var $best_id { value = $best_wrestler|get:$wkey2:null }

                conditional {
                  if ($best_id != null) {
                    var.update $is_starter { value = (($row2.wrestler_id|to_text) == ($best_id|to_text)) }
                  }
                }
              }
            }
          }
        }

        array.push $flags {
          value = {row_id: $row2.row_id, is_starter: $is_starter}
        }
      }
    }
  }

  response = $flags
  guid = "W6yTn3ZkQs8LcRpXo5HvJd7FgBe4"
}

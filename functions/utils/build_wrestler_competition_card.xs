// Shared "quick stats" card for a single wrestler - career record plus
// notable results against wrestlers who are CURRENTLY in the top-15
// composite ranking at their weight. Same underlying shape the rankings
// pages already show (see my_rankings_pool_GET.xs), pulled into a shared
// function so waiver-wire and trade UIs can show the same research context
// without re-deriving it separately.
function build_wrestler_competition_card {
  input {
    int canonical_wrestler_id
    int season_year
  }

  stack {
    db.get canonical_wrestler {
      field_name = "id"
      field_value = $input.canonical_wrestler_id
    } as $w

    var $team_name {
      value = null
    }

    conditional {
      if ($w != null && $w.current_team_id != null) {
        db.get canonical_team {
          field_name = "id"
          field_value = $w.current_team_id
        } as $t

        conditional {
          if ($t != null) {
            var.update $team_name {
              value = $t.name
            }
          }
        }
      }
    }

    db.query wrestler_match_history {
      where = ($db.wrestler_match_history.winner_canonical_wrestler_id == $input.canonical_wrestler_id) || ($db.wrestler_match_history.loser_canonical_wrestler_id == $input.canonical_wrestler_id)
      sort = {wrestler_match_history.occurred_at: "desc"}
      return = {type: "list"}
    } as $all_matches

    var $wins {
      value = 0
    }

    var $losses {
      value = 0
    }

    foreach ($all_matches) {
      each as $m {
        conditional {
          if ($m.winner_canonical_wrestler_id == $input.canonical_wrestler_id) {
            math.add $wins {
              value = 1
            }
          }
          else {
            math.add $losses {
              value = 1
            }
          }
        }
      }
    }

    var $win_pct {
      value = 0
    }

    conditional {
      if (($wins + $losses) > 0) {
        var.update $win_pct {
          value = ($wins / ($wins + $losses))
        }
      }
    }

    // Ranked lookup at THIS wrestler's own weight (their real current weight,
    // not whatever fantasy slot they're being considered for).
    var $weight_int {
      value = null
    }

    conditional {
      if ($w != null && $w.current_weight_class != null) {
        var.update $weight_int {
          value = ($w.current_weight_class|to_int)
        }
      }
    }

    var $ranked_lookup {
      value = {}
    }

    conditional {
      if ($weight_int != null) {
        db.query wrestler_composite_ranking {
          where = ($db.wrestler_composite_ranking.weight == $weight_int) && ($db.wrestler_composite_ranking.season_year == $input.season_year) && ($db.wrestler_composite_ranking.rank <= 15)
          return = {type: "list"}
        } as $ranked_rows

        foreach ($ranked_rows) {
          each as $rr {
            db.get canonical_wrestler {
              field_name = "id"
              field_value = $rr.canonical_wrestler_id
              output = ["id", "display_name"]
            } as $rw

            var.update $ranked_lookup {
              value = $ranked_lookup|set:($rr.canonical_wrestler_id|to_text):{rank: $rr.rank, display_name: $rw|get:"display_name":null}
            }
          }
        }
      }
    }

    var $notable_matches {
      value = []
    }

    foreach ($all_matches) {
      each as $m {
        var $is_winner {
          value = ($m.winner_canonical_wrestler_id == $input.canonical_wrestler_id)
        }

        var $opponent_id {
          value = $m.loser_canonical_wrestler_id
        }

        conditional {
          if ($is_winner == false) {
            var.update $opponent_id {
              value = $m.winner_canonical_wrestler_id
            }
          }
        }

        var $opponent_key {
          value = ($opponent_id|to_text)
        }

        conditional {
          if ($opponent_id != null && ($ranked_lookup|has:$opponent_key)) {
            var $opponent_info {
              value = $ranked_lookup|get:$opponent_key:null
            }

            array.push $notable_matches {
              value = {
                is_winner    : $is_winner
                opponent_id  : $opponent_id
                opponent_name: $opponent_info.display_name
                opponent_rank: $opponent_info.rank
                victory_type : $m.victory_type
                score        : $m.score
                event_name   : $m.event_name
                occurred_at  : $m.occurred_at
              }
            }
          }
        }
      }
    }
  }

  response = {
    canonical_wrestler_id: $input.canonical_wrestler_id
    display_name         : $w|get:"display_name":null
    team_name            : $team_name
    weight               : $weight_int
    wins                 : $wins
    losses               : $losses
    win_pct              : $win_pct
    notable_matches      : $notable_matches
  }
  guid = "W4tRq9SuMp2XcVo6HzYr8FbLgDj7"
}

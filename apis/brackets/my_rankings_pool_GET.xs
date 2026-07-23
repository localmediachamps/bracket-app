// Candidate pool for MY personal rankings "add" panel - identical logic to
// admin/rankings/pool (every wrestler at this weight, enriched with record +
// wins over the OFFICIAL top-15, sorted strongest-first) but usable by any
// logged-in user, not admin-gated.
query "my/rankings/pool" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    int weight
    int season_year
    text? q? filters=trim|max:100
  }

  stack {
    var $q_lower {
      value = $input.q|to_lower
    }

    var $weight_text {
      value = ($input.weight|to_text)
    }

    db.query canonical_wrestler {
      where = ($db.canonical_wrestler.current_weight_class == $weight_text) && ($input.q == null || (($db.canonical_wrestler.display_name|to_lower) includes $q_lower))
      return = {type: "list"}
    } as $candidates

    // Current top-15 at this weight/season - who a "win over" counts against
    db.query wrestler_composite_ranking {
      where = ($db.wrestler_composite_ranking.weight == $input.weight) && ($db.wrestler_composite_ranking.season_year == $input.season_year) && ($db.wrestler_composite_ranking.rank <= 15)
      return = {type: "list"}
    } as $ranked_rows

    var $ranked_lookup {
      value = {}
    }

    foreach ($ranked_rows) {
      each as $rr {
        db.get canonical_wrestler {
          field_name = "id"
          field_value = $rr.canonical_wrestler_id
        } as $rw

        var.update $ranked_lookup {
          value = $ranked_lookup|set:($rr.canonical_wrestler_id|to_text):{rank: $rr.rank, display_name: $rw|get:"display_name":null}
        }
      }
    }

    // Every ranking I've ALREADY given this same wrestler at a DIFFERENT
    // weight this season - warns before creating an accidental conflict
    // (e.g. ranking someone at 133 who's already on my own list at 149).
    // Filtered to weight != this weight up front so a same-wrestler row at
    // the CURRENT weight can never overwrite/hide a real conflict at
    // another weight in the id-keyed lookup below.
    db.query user_wrestler_ranking {
      where = ($db.user_wrestler_ranking.user_id == $auth.id) && ($db.user_wrestler_ranking.season_year == $input.season_year) && ($db.user_wrestler_ranking.weight != $input.weight)
      return = {type: "list"}
    } as $my_ranked_rows

    var $ranked_elsewhere_lookup {
      value = {}
    }

    foreach ($my_ranked_rows) {
      each as $mrr {
        var.update $ranked_elsewhere_lookup {
          value = $ranked_elsewhere_lookup|set:($mrr.canonical_wrestler_id|to_text):{weight: $mrr.weight, rank: $mrr.rank}
        }
      }
    }

    var $season_bounds {
      value = [
        {label: "2025-26", start: 1754006400000, end: 1785628799000}
        {label: "2024-25", start: 1722470400000, end: 1754006399000}
        {label: "2023-24", start: 1690848000000, end: 1722470399000}
        {label: "2022-23", start: 1659312000000, end: 1690847999000}
      ]
    }

    var $out {
      value = []
    }

    foreach ($candidates) {
      each as $c {
        db.query wrestler_match_history {
          where = ($db.wrestler_match_history.winner_canonical_wrestler_id == $c.id) || ($db.wrestler_match_history.loser_canonical_wrestler_id == $c.id)
          sort = {wrestler_match_history.occurred_at: "desc"}
          return = {type: "list"}
        } as $all_matches

        var $team_name {
          value = null
        }

        conditional {
          if ($c.current_team_id != null) {
            db.get canonical_team {
              field_name = "id"
              field_value = $c.current_team_id
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

        // Most-recent season that has any match data
        var $record_wins {
          value = 0
        }

        var $record_losses {
          value = 0
        }

        var $record_season {
          value = null
        }

        foreach ($season_bounds) {
          each as $sb {
            conditional {
              if ($record_season == null) {
                var $season_wins {
                  value = 0
                }

                var $season_losses {
                  value = 0
                }

                foreach ($all_matches) {
                  each as $m {
                    conditional {
                      if ($m.occurred_at >= $sb.start && $m.occurred_at <= $sb.end) {
                        conditional {
                          if ($m.winner_canonical_wrestler_id == $c.id) {
                            math.add $season_wins {
                              value = 1
                            }
                          }
                          else {
                            math.add $season_losses {
                              value = 1
                            }
                          }
                        }
                      }
                    }
                  }
                }

                conditional {
                  if (($season_wins + $season_losses) > 0) {
                    var.update $record_season {
                      value = $sb.label
                    }

                    var.update $record_wins {
                      value = $season_wins
                    }

                    var.update $record_losses {
                      value = $season_losses
                    }
                  }
                }
              }
            }
          }
        }

        // Career wins over a currently top-15-ranked wrestler
        var $wins_over_ranked {
          value = []
        }

        foreach ($all_matches) {
          each as $m {
            conditional {
              if ($m.winner_canonical_wrestler_id == $c.id) {
                var $loser_key {
                  value = ($m.loser_canonical_wrestler_id|to_text)
                }

                conditional {
                  if ($m.loser_canonical_wrestler_id != null && ($ranked_lookup|has:$loser_key)) {
                    var $opp_info {
                      value = $ranked_lookup|get:$loser_key:null
                    }

                    array.push $wins_over_ranked {
                      value = {
                        opponent_name: $opp_info.display_name
                        opponent_rank: $opp_info.rank
                        victory_type : $m.victory_type
                        score        : $m.score
                        occurred_at  : $m.occurred_at
                      }
                    }
                  }
                }
              }
            }
          }
        }

        var $win_pct {
          value = 0
        }

        conditional {
          if (($record_wins + $record_losses) > 0) {
            var.update $win_pct {
              value = ($record_wins / ($record_wins + $record_losses))
            }
          }
        }

        var $ranked_elsewhere {
          value = null
        }

        var $c_key {
          value = ($c.id|to_text)
        }

        conditional {
          if ($ranked_elsewhere_lookup|has:$c_key) {
            var $existing_rank {
              value = $ranked_elsewhere_lookup|get:$c_key:null
            }

            conditional {
              if ($existing_rank.weight != $input.weight) {
                var.update $ranked_elsewhere {
                  value = $existing_rank
                }
              }
            }
          }
        }

        // Only surface wrestlers active in the most recent completed season
        // (2025-26) - no class-year data exists yet to know exactly who
        // graduated, but "hasn't appeared in the most recent season at all"
        // is a reliable enough signal to exclude someone whose last known
        // activity is multiple years stale.
        conditional {
          if ($record_season == "2025-26") {
            array.push $out {
              value = {
                id                : $c.id
                display_name      : $c.display_name
                current_team      : ($team_name == null ? null : {name: $team_name})
                record_wins       : $record_wins
                record_losses     : $record_losses
                record_season     : $record_season
                win_pct           : $win_pct
                wins_over_ranked  : $wins_over_ranked
                has_beaten_ranked : (($wins_over_ranked|count) > 0)
                ranked_elsewhere  : $ranked_elsewhere
              }
            }
          }
        }
      }
    }

    // Sort: beat a ranked wrestler first, then by win% desc, then name asc
    var $sorted_by_name {
      value = $out|sort:"display_name":"text"
    }

    var $sorted_by_pct {
      value = $sorted_by_name|sort:"win_pct":"number"|reverse
    }

    var $beat_ranked {
      value = []
    }

    var $rest {
      value = []
    }

    foreach ($sorted_by_pct) {
      each as $o {
        conditional {
          if ($o.has_beaten_ranked) {
            array.push $beat_ranked {
              value = $o
            }
          }
          else {
            array.push $rest {
              value = $o
            }
          }
        }
      }
    }

    var $final {
      value = ($beat_ranked|merge:$rest)
    }
  }

  response = {
    items: $final
  }
  guid = "F2wRq6XvNs9TcYpLo4HbFd7GkVi3"
}

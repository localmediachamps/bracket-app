// Scores every lineup (and its lineup_slots) for one (league, season_week)
// pair - shared by both the head_to_head and conference/nationals branches
// of tasks/score_league_weeks.xs, since both use the exact same roster/
// lineup-averaging scoring math (fantasy league plan, Phase 6). The caller
// is responsible for anything week-type-specific afterward: head_to_head
// compares the two sides of a matchup and updates win/loss records;
// conference/nationals just weight the resulting lineup.points at
// standings-computation time (not built yet - out of scope this increment).
//
// Per real match: base victory_points[victory_type] (0 if this wrestler
// lost - losses count as 0 toward the average), times an opponent-quality
// multiplier looked up against wrestler_composite_ranking - same tier
// lookup shape as functions/scoring/score_entry.xs's bracket/pickem scorer,
// a graceful no-op (1x) until that table has real rows. lineup_slot.points
// is the AVERAGE of per-match points across the week (not a sum), plus a
// flat medal_bonus if one of the week's matches was an "Nth Place Match"
// (round_label parsed the same way Results.jsx's placementInfo() does -
// winner of that match takes the Nth place, loser takes N+1th).
function score_league_lineups_for_week {
  input {
    int league_id
    int season_week_id
    timestamp week_starts_at
    timestamp week_ends_at
    int season_year
    json victory_points
    json medal_bonus
    json opponent_multipliers
  }

  stack {
    db.query lineup {
      where = $db.lineup.league_id == $input.league_id && $db.lineup.season_week_id == $input.season_week_id
      return = {type: "list"}
    } as $lineups

    var $lineups_scored {
      value = 0
    }

    foreach ($lineups) {
      each as $lineup {
        try_catch {
          try {
            db.query lineup_slot {
              where = $db.lineup_slot.lineup_id == $lineup.id
              return = {type: "list"}
            } as $slots

            var $lineup_total {
              value = 0
            }

            foreach ($slots) {
              each as $slot {
                db.query wrestler_match_history {
                  where = (($db.wrestler_match_history.winner_canonical_wrestler_id == $slot.canonical_wrestler_id) || ($db.wrestler_match_history.loser_canonical_wrestler_id == $slot.canonical_wrestler_id)) && ($db.wrestler_match_history.occurred_at >= $input.week_starts_at) && ($db.wrestler_match_history.occurred_at <= $input.week_ends_at)
                  return = {type: "list"}
                } as $matches

                // match_count only counts matches with a real, classifiable
                // victory_type - "No Contest" and unrecognized raw text are
                // excluded entirely (not zero-scored), see
                // normalize_victory_type.xs's header comment
                var $match_count {
                  value = 0
                }

                var $points_sum {
                  value = 0
                }

                var $medal_amount {
                  value = 0
                }

                var $breakdown {
                  value = []
                }

                foreach ($matches) {
                  each as $m {
                    function.run normalize_victory_type {
                      input = {raw: $m.victory_type}
                    } as $normalized_victory_type

                    conditional {
                      if ($normalized_victory_type != null) {
                        math.add $match_count {
                          value = 1
                        }

                        var $is_winner {
                          value = $m.winner_canonical_wrestler_id == $slot.canonical_wrestler_id
                        }

                        var $base_points {
                          value = 0
                        }

                        conditional {
                          if ($is_winner) {
                            var.update $base_points {
                              value = $input.victory_points|get:$normalized_victory_type:($input.victory_points|get:"default":0)
                            }
                          }
                        }

                        // Opponent-quality multiplier - mirrors score_entry.xs's
                        // lookup against wrestler_composite_ranking exactly
                        var $opponent_wrestler_id {
                          value = null
                        }

                        conditional {
                          if ($is_winner) {
                            var.update $opponent_wrestler_id {
                              value = $m.loser_canonical_wrestler_id
                            }
                          }
                          else {
                            var.update $opponent_wrestler_id {
                              value = $m.winner_canonical_wrestler_id
                            }
                          }
                        }

                        var $multiplier {
                          value = 1
                        }

                        conditional {
                          if ($opponent_wrestler_id != null) {
                            db.query wrestler_composite_ranking {
                              where = ($db.wrestler_composite_ranking.canonical_wrestler_id == $opponent_wrestler_id) && ($db.wrestler_composite_ranking.season_year == $input.season_year)
                              return = {type: "single"}
                            } as $opp_ranking

                            conditional {
                              if ($opp_ranking != null) {
                                var $contender {
                                  value = $input.opponent_multipliers|get:"contender":null
                                }

                                var $all_american {
                                  value = $input.opponent_multipliers|get:"all_american":null
                                }

                                var $blood_round {
                                  value = $input.opponent_multipliers|get:"blood_round":null
                                }

                                conditional {
                                  if ($contender != null && $opp_ranking.rank >= $contender.min_rank && $opp_ranking.rank <= $contender.max_rank) {
                                    var.update $multiplier {
                                      value = $contender.multiplier
                                    }
                                  }
                                  elseif ($all_american != null && $opp_ranking.rank >= $all_american.min_rank && $opp_ranking.rank <= $all_american.max_rank) {
                                    var.update $multiplier {
                                      value = $all_american.multiplier
                                    }
                                  }
                                  elseif ($blood_round != null && $opp_ranking.rank >= $blood_round.min_rank && $opp_ranking.rank <= $blood_round.max_rank) {
                                    var.update $multiplier {
                                      value = $blood_round.multiplier
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }

                        var $match_points {
                          value = $base_points * $multiplier
                        }

                        math.add $points_sum {
                          value = $match_points
                        }

                        // Medal bonus - only a real "Nth Place Match" counts;
                        // winner takes the Nth place, loser takes N+1th
                        conditional {
                          if ($m.round_label != null) {
                            text.icontains $m.round_label {
                              value = "place match"
                            } as $is_placement_match

                            conditional {
                              if ($is_placement_match) {
                                // "/^\d+/" is unsafe here - a bare \d inside
                                // a XanoScript string literal gets corrupted
                                // (confirmed 2026-07-22); use an [0-9]
                                // character class instead. regex_get_first_match
                                // returns [full_match, group1, ...], not a
                                // plain string - take element 0.
                                var $placement_matches {
                                  value = "/^([0-9]+)/"|regex_get_first_match:$m.round_label
                                }

                                var $placement_num_text {
                                  value = $placement_matches|get:0:null
                                }

                                conditional {
                                  if ($placement_num_text != null && $placement_num_text != "") {
                                    var $placement_num {
                                      value = $placement_num_text|to_int
                                    }

                                    conditional {
                                      if ($is_winner == false) {
                                        math.add $placement_num {
                                          value = 1
                                        }
                                      }
                                    }

                                    var $placement_key {
                                      value = $placement_num|to_text
                                    }

                                    var.update $medal_amount {
                                      value = $input.medal_bonus|get:$placement_key:($input.medal_bonus|get:"default":0)
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }

                        array.push $breakdown {
                          value = {
                            match_id           : $m.id
                            is_winner          : $is_winner
                            victory_type       : $normalized_victory_type
                            base_points        : $base_points
                            opponent_multiplier: $multiplier
                            match_points       : $match_points
                          }
                        }
                      }
                    }
                  }
                }

                var $avg_points {
                  value = 0
                }

                conditional {
                  if ($match_count > 0) {
                    var.update $avg_points {
                      value = $points_sum / $match_count
                    }
                  }
                }

                var $slot_total {
                  value = $avg_points + $medal_amount
                }

                db.edit lineup_slot {
                  field_name = "id"
                  field_value = $slot.id
                  data = {
                    points           : $slot_total
                    match_count      : $match_count
                    medal_bonus      : $medal_amount
                    scoring_breakdown: $breakdown
                    competed         : $match_count > 0
                  }
                } as $updated_slot

                math.add $lineup_total {
                  value = $slot_total
                }
              }
            }

            db.edit lineup {
              field_name = "id"
              field_value = $lineup.id
              data = {
                points: $lineup_total
                status: "scored"
              }
            } as $updated_lineup

            math.add $lineups_scored {
              value = 1
            }
          }

          catch {
            debug.log {
              value = {lineup_id: $lineup.id, error: $error.message}
            }
          }
        }
      }
    }
  }

  response = {lineups_scored: $lineups_scored}
  guid = "WtV7ln8SIZWFMfdrTSLKuMaHNvQ"
}

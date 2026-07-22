// Full idempotent rescore + re-rank of a dual_meet's entries, using the
// fixed rubric (not percentile) scoring path - see dual_rubric_scoring_design
// memory and get_default_platform_leaderboard_config.xs's rubric_tiers.
//
// Weight-nullification rule: a dual_meet_weight_slot with occurred == false
// (the predicted match never actually happened - injury swap, lineup
// change) is excluded from BOTH the numerator and denominator entirely, for
// every entry - never scored as a miss. occurred_weight_count is therefore
// the true denominator each entry is graded against, which can vary meet to
// meet but is fixed for all entries within the same dual_meet.
//
// Tier assignment: perfect_card (every occurred weight's winner AND victory
// type both correct) and all_winners (every winner correct, but not every
// type) are both zero-missed-winner tiers; miss_1/miss_2/miss_3 are keyed by
// (occurred_weight_count - correct_winner_count), so a 9-of-10 card and an
// 8-of-9 card (one weight nullified) land on the same "miss_1" tier - the
// rubric grades against what could be predicted, not a fixed field size.
// 4+ missed winners falls through to "default" (0 points).
function rescore_dual_meet {
  input {
    // Dual meet to rescore
    int dual_meet_id
  }

  stack {
    db.get dual_meet {
      field_name = "id"
      field_value = $input.dual_meet_id
    } as $dual_meet

    precondition ($dual_meet != null) {
      error_type = "notfound"
      error = "Dual meet not found."
    }

    db.query dual_meet_weight_slot {
      where = $db.dual_meet_weight_slot.dual_meet_id == $input.dual_meet_id
      return = {type: "list"}
    } as $all_slots

    // Only weights that actually happened count toward scoring at all
    var $graded_slots {
      value = $all_slots|filter:$$.occurred == true
    }

    var $occurred_weight_count {
      value = $graded_slots|count
    }

    function.run get_default_platform_leaderboard_config {
      input = {}
    } as $platform_config

    db.query dual_meet_entry {
      where = $db.dual_meet_entry.dual_meet_id == $input.dual_meet_id && ($db.dual_meet_entry.status == "submitted" || $db.dual_meet_entry.status == "locked" || $db.dual_meet_entry.status == "scored")
      return = {type: "list"}
    } as $entries

    var $scored_count {
      value = 0
    }

    foreach ($entries) {
      each as $entry {
        db.query dual_meet_pick {
          where = $db.dual_meet_pick.entry_id == $entry.id
          return = {type: "list"}
        } as $picks

        // Index picks by weight_slot_id for quick lookup
        var $pick_by_slot {
          value = {}
        }

        foreach ($picks) {
          each as $p {
            var $pkey {
              value = $p.weight_slot_id|to_text
            }

            var.update $pick_by_slot {
              value = $pick_by_slot|set:$pkey:$p
            }
          }
        }

        var $correct_winner_count {
          value = 0
        }

        var $correct_type_count {
          value = 0
        }

        foreach ($graded_slots) {
          each as $slot {
            var $skey {
              value = $slot.id|to_text
            }

            var $matching_pick {
              value = null
            }

            conditional {
              if ($pick_by_slot|has:$skey) {
                var.update $matching_pick {
                  value = $pick_by_slot|get:$skey:null
                }
              }
            }

            var $winner_correct {
              value = false
            }

            var $type_correct {
              value = false
            }

            conditional {
              if ($matching_pick != null) {
                conditional {
                  if ($matching_pick.picked_side == $slot.actual_winner_side) {
                    var.update $winner_correct {
                      value = true
                    }

                    math.add $correct_winner_count {
                      value = 1
                    }

                    conditional {
                      if ($matching_pick.picked_victory_type == $slot.actual_victory_type) {
                        var.update $type_correct {
                          value = true
                        }

                        math.add $correct_type_count {
                          value = 1
                        }
                      }
                    }
                  }
                }

                db.edit dual_meet_pick {
                  field_name = "id"
                  field_value = $matching_pick.id
                  data = {is_correct_winner: $winner_correct, is_correct_type: $type_correct}
                } as $updated_pick
              }
            }
          }
        }

        var $miss_count {
          value = $occurred_weight_count - $correct_winner_count
        }

        var $tier {
          value = "default"
        }

        conditional {
          if ($occurred_weight_count > 0 && $miss_count == 0 && $correct_type_count == $occurred_weight_count) {
            var.update $tier {
              value = "perfect_card"
            }
          }
          elseif ($occurred_weight_count > 0 && $miss_count == 0) {
            var.update $tier {
              value = "all_winners"
            }
          }
          elseif ($miss_count == 1) {
            var.update $tier {
              value = "miss_1"
            }
          }
          elseif ($miss_count == 2) {
            var.update $tier {
              value = "miss_2"
            }
          }
          elseif ($miss_count == 3) {
            var.update $tier {
              value = "miss_3"
            }
          }
        }

        var $tier_points {
          value = 0
        }

        conditional {
          if ($platform_config.rubric_tiers|has:$tier) {
            var.update $tier_points {
              value = $platform_config.rubric_tiers|get:$tier:0
            }
          }
        }

        db.edit dual_meet_entry {
          field_name = "id"
          field_value = $entry.id
          data = {
            status               : "scored"
            correct_winner_count : $correct_winner_count
            correct_type_count   : $correct_type_count
            occurred_weight_count: $occurred_weight_count
            rubric_tier          : $tier
            total_points         : $tier_points
            updated_at           : now
          }
        } as $updated_entry

        math.add $scored_count {
          value = 1
        }
      }
    }

    // Re-rank: reload fresh totals, order by total_points desc (id asc final tiebreak)
    db.query dual_meet_entry {
      where = $db.dual_meet_entry.dual_meet_id == $input.dual_meet_id && ($db.dual_meet_entry.status == "submitted" || $db.dual_meet_entry.status == "locked" || $db.dual_meet_entry.status == "scored")
      return = {type: "list"}
    } as $fresh_entries

    var $rank_pool {
      value = []
    }

    foreach ($fresh_entries) {
      each as $fe {
        array.push $rank_pool {
          value = $fe
        }
      }
    }

    var $competitive_count {
      value = $rank_pool|count
    }

    var $ranked {
      value = []
    }

    while (($rank_pool|count) > 0) {
      each {
        var $best {
          value = $rank_pool|first
        }

        foreach ($rank_pool) {
          each as $cand {
            var $cand_total {
              value = $cand.total_points|first_notnull:0
            }

            var $best_total {
              value = $best.total_points|first_notnull:0
            }

            conditional {
              if ($cand_total > $best_total || ($cand_total == $best_total && $cand.id < $best.id)) {
                var.update $best {
                  value = $cand
                }
              }
            }
          }
        }

        array.push $ranked {
          value = $best
        }

        var.update $rank_pool {
          value = $rank_pool|remove:$best
        }
      }
    }

    var $ranked_count {
      value = $ranked|count
    }

    for ($ranked_count) {
      each as $ridx {
        var $rentry {
          value = $ranked[$ridx]
        }

        var $new_rank {
          value = $ridx + 1
        }

        db.edit dual_meet_entry {
          field_name = "id"
          field_value = $rentry.id
          data = {
            prev_rank : $rentry.rank
            rank      : $new_rank
            updated_at: now
          }
        } as $ranked_entry

        // Master leaderboard ledger - rubric path, dual_meet_id instead of
        // tournament_id
        db.query platform_leaderboard_entry {
          where = $db.platform_leaderboard_entry.user_id == $rentry.user_id && $db.platform_leaderboard_entry.dual_meet_id == $input.dual_meet_id && $db.platform_leaderboard_entry.source_type == "dual_meet"
          return = {type: "single"}
        } as $existing_ple

        conditional {
          if ($existing_ple != null) {
            db.edit platform_leaderboard_entry {
              field_name = "id"
              field_value = $existing_ple.id
              data = {
                rubric_tier   : $rentry.rubric_tier
                points_awarded: $rentry.total_points
                scoring_path  : "rubric"
                year          : $dual_meet.year
              }
            } as $updated_ple
          }
          else {
            db.add platform_leaderboard_entry {
              data = {
                created_at    : now
                user_id       : $rentry.user_id
                dual_meet_id  : $input.dual_meet_id
                source_type   : "dual_meet"
                scoring_path  : "rubric"
                rubric_tier   : $rentry.rubric_tier
                points_awarded: $rentry.total_points
                year          : $dual_meet.year
              }
            } as $new_ple
          }
        }
      }
    }

    db.edit dual_meet {
      field_name = "id"
      field_value = $input.dual_meet_id
      data = {needs_rescore: false, entry_count: $competitive_count}
    } as $updated_dual_meet
  }

  response = {
    entries_scored       : $scored_count
    entries_ranked       : $ranked_count
    occurred_weight_count: $occurred_weight_count
  }
  guid = "Vp8nRwXt2QoZmYlDcAe6BfK9jHd"
}

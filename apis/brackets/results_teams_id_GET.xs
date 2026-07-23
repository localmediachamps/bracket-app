// Team profile: identity, roster by season (from canonical_wrestler_team,
// joined to canonical_wrestler for display names), and a schedule slot for
// when real prospective-schedule data exists (Garrett will supply real
// event dates directly once the season is closer - see project notes; no
// scraped schedule pipeline exists yet, so this is intentionally empty for
// now rather than faked). Public, same as the rest of the results explorer.
query "results/teams/{id}" verb=GET {
  api_group = "brackets"

  input {
    int id
  }

  stack {
    db.get canonical_team {
      field_name = "id"
      field_value = $input.id
    } as $team

    precondition ($team != null) {
      error_type = "notfound"
      error = "Team not found."
    }

    db.query canonical_wrestler_team {
      where = $db.canonical_wrestler_team.canonical_team_id == $input.id
      return = {type: "list"}
    } as $links

    // Small per-team roster (dozens, not hundreds) - fetch each linked
    // wrestler individually rather than needing an unsupported "id in list"
    // where-clause shape. Loops over $links directly (not deduped) so every
    // field_value passed to db.get stays a real int from the row itself,
    // not a re-derived map key (object keys come back as text via |keys,
    // which risks a silent type-mismatch non-match against an int column).
    var $wrestler_name_map {
      value = {}
    }

    // Denormalized current_weight_class - used as the 2026-27 tab's weight
    // display, since that season has no real matches yet to derive it from.
    var $wrestler_weight_map {
      value = {}
    }

    foreach ($links) {
      each as $l {
        conditional {
          if (($wrestler_name_map|has:$l.canonical_wrestler_id) == false) {
            db.get canonical_wrestler {
              field_name = "id"
              field_value = $l.canonical_wrestler_id
            } as $w

            conditional {
              if ($w != null) {
                var.update $wrestler_name_map {
                  value = $wrestler_name_map|set:$w.id:$w.display_name
                }

                var.update $wrestler_weight_map {
                  value = $wrestler_weight_map|set:$w.id:$w.current_weight_class
                }
              }
            }
          }
        }
      }
    }

    // Group roster links by season, newest (including the not-yet-started
    // upcoming season) first
    var $season_order {
      value = ["2026-27", "2025-26", "2024-25", "2023-24", "2022-23"]
    }

    // Same academic-year windows as results/wrestlers/{id} - used to find a
    // representative match (for its weight_class) within this specific
    // season, since canonical_wrestler_team doesn't store weight itself.
    var $season_bounds {
      value = {
        "2022-23": {start: 1659312000000, end: 1690847999000}
        "2023-24": {start: 1690848000000, end: 1722470399000}
        "2024-25": {start: 1722470400000, end: 1754006399000}
        "2025-26": {start: 1754006400000, end: 1785628799000}
      }
    }

    var $roster_by_season {
      value = {}
    }

    foreach ($links) {
      each as $l {
        var $season_list {
          value = []
        }

        conditional {
          if ($roster_by_season|has:$l.season_label) {
            var.update $season_list {
              value = $roster_by_season[$l.season_label]
            }
          }
        }

        var $weight_class {
          value = null
        }

        var $season_wins {
          value = 0
        }

        var $season_losses {
          value = 0
        }

        var $bounds {
          value = $season_bounds[$l.season_label]
        }

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
                    var.update $weight_class {
                      value = $sm.weight_class
                    }
                  }
                }

                conditional {
                  if ($sm.winner_canonical_wrestler_id == $l.canonical_wrestler_id) {
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

        // The 2026-27 season hasn't started - no matches exist to derive a
        // weight from yet (fall back to the wrestler's denormalized current
        // weight) or a season record from. Pull forward their career record
        // instead so the tab isn't just a wall of 0-0s.
        var $career_wins { value = null }
        var $career_losses { value = null }

        conditional {
          if ($l.season_label == "2026-27") {
            conditional {
              if ($weight_class == null) {
                var.update $weight_class {
                  value = $wrestler_weight_map[$l.canonical_wrestler_id]
                }
              }
            }

            db.query wrestler_match_history {
              where = ($db.wrestler_match_history.winner_canonical_wrestler_id == $l.canonical_wrestler_id) || ($db.wrestler_match_history.loser_canonical_wrestler_id == $l.canonical_wrestler_id)
              return = {type: "list"}
            } as $career_matches

            var.update $career_wins { value = 0 }
            var.update $career_losses { value = 0 }

            foreach ($career_matches) {
              each as $cm {
                conditional {
                  if ($cm.winner_canonical_wrestler_id == $l.canonical_wrestler_id) {
                    math.add $career_wins { value = 1 }
                  }
                  else {
                    math.add $career_losses { value = 1 }
                  }
                }
              }
            }
          }
        }

        array.push $season_list {
          value = {
            wrestler_id  : $l.canonical_wrestler_id
            display_name : $wrestler_name_map[$l.canonical_wrestler_id]
            weight_class : $weight_class
            match_count  : $l.match_count
            wins         : $season_wins
            losses       : $season_losses
            career_wins  : $career_wins
            career_losses: $career_losses
            is_starter_override: $l.is_starter_override
          }
        }

        var.update $roster_by_season {
          value = $roster_by_season|set:$l.season_label:$season_list
        }
      }
    }

    var $roster_out {
      value = []
    }

    foreach ($season_order) {
      each as $season {
        conditional {
          if ($roster_by_season|has:$season) {
            var $sorted {
              value = $roster_by_season[$season]|sort:"weight_class":"text"
            }

            var $starter_best_id {
              value = {}
            }

            var $starter_best_score {
              value = {}
            }

            var $starter_forced_id {
              value = {}
            }

            foreach ($sorted) {
              each as $sw {
                var $sw_key {
                  value = ($sw.weight_class|to_text)
                }

                var $sw_score {
                  value = ($sw.wins + $sw.losses)
                }

                conditional {
                  if ($sw.is_starter_override != null && $sw.is_starter_override == true) {
                    var.update $starter_forced_id {
                      value = $starter_forced_id|set:$sw_key:$sw.wrestler_id
                    }
                  }
                }

                var $sw_prev_score {
                  value = $starter_best_score|get:$sw_key:null
                }

                conditional {
                  if ($sw_prev_score == null) {
                    var.update $starter_best_score {
                      value = $starter_best_score|set:$sw_key:$sw_score
                    }

                    var.update $starter_best_id {
                      value = $starter_best_id|set:$sw_key:$sw.wrestler_id
                    }
                  }
                  elseif ($sw_score > $sw_prev_score) {
                    var.update $starter_best_score {
                      value = $starter_best_score|set:$sw_key:$sw_score
                    }

                    var.update $starter_best_id {
                      value = $starter_best_id|set:$sw_key:$sw.wrestler_id
                    }
                  }
                }
              }
            }

            var $with_starters {
              value = []
            }

            foreach ($sorted) {
              each as $sw2 {
                var $sw2_key {
                  value = ($sw2.weight_class|to_text)
                }

                var $sw2_is_starter {
                  value = false
                }

                conditional {
                  if ($starter_forced_id|has:$sw2_key) {
                    var $sw2_forced {
                      value = $starter_forced_id|get:$sw2_key:null
                    }

                    // `int == int` is fatal here whenever either operand came
                    // from a map |get lookup (confirmed via bisection
                    // 2026-07-23 - crashes even null-guarded, with either
                    // operand order; `>` on the same kind of value is fine,
                    // see $sw_score > $sw_prev_score above). Casting both
                    // sides to text before comparing avoids it.
                    var.update $sw2_is_starter {
                      value = (($sw2.wrestler_id|to_text) == ($sw2_forced|to_text))
                    }
                  }
                  elseif ($sw2.is_starter_override != null && $sw2.is_starter_override == false) {
                    var.update $sw2_is_starter {
                      value = false
                    }
                  }
                  else {
                    var $sw2_best {
                      value = $starter_best_id|get:$sw2_key:null
                    }

                    conditional {
                      if ($sw2_best != null) {
                        var.update $sw2_is_starter {
                          value = (($sw2.wrestler_id|to_text) == ($sw2_best|to_text))
                        }
                      }
                    }
                  }
                }

                array.push $with_starters {
                  value = {
                    wrestler_id       : $sw2.wrestler_id
                    display_name      : $sw2.display_name
                    weight_class      : $sw2.weight_class
                    match_count       : $sw2.match_count
                    wins              : $sw2.wins
                    losses            : $sw2.losses
                    career_wins       : $sw2.career_wins
                    career_losses     : $sw2.career_losses
                    is_starter_override: $sw2.is_starter_override
                    is_starter        : $sw2_is_starter
                  }
                }
              }
            }

            array.push $roster_out {
              value = {
                season_label: $season
                wrestlers   : $with_starters
              }
            }
          }
        }
      }
    }

    // Real dual-meet schedule + results, built from the historical dual_meet
    // rows reconciled from wrestler_match_history (functions/analytics/
    // reconcile_historical_dual_meets.xs) - these are actual past events, not
    // a forward-looking schedule (no prospective-schedule data source exists
    // yet - see the module docstring), so this covers "how did they do this
    // season" for completed seasons, not upcoming matchups.
    db.query dual_meet {
      where = ($db.dual_meet.home_canonical_team_id == $input.id || $db.dual_meet.away_canonical_team_id == $input.id) && $db.dual_meet.is_historical == true
      sort = {dual_meet.occurred_at: "desc"}
      return = {type: "list"}
    } as $dual_meets

    var $schedule_by_season {
      value = {}
    }

    foreach ($dual_meets) {
      each as $dm {
        var $is_home {
          value = $dm.home_canonical_team_id == $input.id
        }

        var $opponent_name {
          value = ($is_home ? $dm.away_team_name : $dm.home_team_name)
        }

        var $opponent_team_id {
          value = ($is_home ? $dm.away_canonical_team_id : $dm.home_canonical_team_id)
        }

        var $own_score {
          value = ($is_home ? $dm.home_score : $dm.away_score)
        }

        var $opp_score {
          value = ($is_home ? $dm.away_score : $dm.home_score)
        }

        var $dm_result {
          value = "pending"
        }

        conditional {
          if ($own_score != null && $opp_score != null) {
            conditional {
              if ($own_score > $opp_score) {
                var.update $dm_result { value = "win" }
              }
              elseif ($own_score < $opp_score) {
                var.update $dm_result { value = "loss" }
              }
              else {
                var.update $dm_result { value = "tie" }
              }
            }
          }
        }

        // Same academic-year season windows already used for the roster tabs
        var $dm_season {
          value = null
        }

        foreach ($season_order) {
          each as $season_key {
            conditional {
              if ($dm_season == null && ($season_bounds|has:$season_key)) {
                var $sb {
                  value = $season_bounds[$season_key]
                }

                conditional {
                  if ($dm.occurred_at != null && $dm.occurred_at >= $sb.start && $dm.occurred_at <= $sb.end) {
                    var.update $dm_season {
                      value = $season_key
                    }
                  }
                }
              }
            }
          }
        }

        conditional {
          if ($dm_season != null) {
            var $dm_list {
              value = []
            }

            conditional {
              if ($schedule_by_season|has:$dm_season) {
                var.update $dm_list {
                  value = $schedule_by_season[$dm_season]
                }
              }
            }

            array.push $dm_list {
              value = {
                dual_meet_id   : $dm.id
                slug           : $dm.slug
                opponent_name  : $opponent_name
                opponent_team_id: $opponent_team_id
                is_home        : $is_home
                occurred_at    : $dm.occurred_at
                own_score      : $own_score
                opp_score      : $opp_score
                result         : $dm_result
              }
            }

            var.update $schedule_by_season {
              value = $schedule_by_season|set:$dm_season:$dm_list
            }
          }
        }
      }
    }

    var $schedule_out {
      value = []
    }

    foreach ($season_order) {
      each as $season {
        conditional {
          if ($schedule_by_season|has:$season) {
            array.push $schedule_out {
              value = {
                season_label: $season
                duals       : $schedule_by_season[$season]
              }
            }
          }
        }
      }
    }
  }

  response = {
    team    : {
      id        : $team.id
      name      : $team.name
      state     : $team.state
      conference: $team.conference
      roster_url: $team.roster_url
      schedule_url: $team.schedule_url
      logo_url: $team.logo_url
    }
    roster  : $roster_out
    schedule: $schedule_out
  }
  guid = "Nq7tXpZv5RwCmYkLbFo2DjH6uAe"
}

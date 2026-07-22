// Weekly fantasy-league scoring bridge (fantasy league plan, Phase 6; the
// conference/nationals branch was redesigned 2026-07-22 - see memory:
// conference_nationals_scoring_redesign - to be roster-ranked rather than
// head-to-head). Modeled on tasks/lock_tournaments.xs / tasks/auto_score.xs's
// established pattern: time-threshold query -> foreach with per-record
// try_catch, never abort the whole run -> nested per-user notify each in its
// own try_catch -> closing debug.log summary. Nothing else transitions
// season_week.status, so this task owns that lifecycle end to end
// (upcoming/open -> locked, on starts_at; locked -> complete, on ends_at +
// a settle buffer for late-arriving results).
//
// EVERY week type writes into the SAME season_week_tournament_result table -
// this is the single unified season-long points ledger the eventual league
// champion is decided from (sum awarded_points per membership across the
// whole season). Branches by week_type:
//   head_to_head        - lineup/lineup_slot scoring (functions/league/
//                          score_league_lineups_for_week) decides each
//                          matchup's winner (updates league_membership
//                          wins/losses/points_for/against as before), then
//                          the win/tie/loss result itself is converted into
//                          flat ledger points (league.scoring_config's
//                          head_to_head_result_points) and written as a
//                          season_week_tournament_result row per side.
//   marquee_tournament   - no roster/lineup scoring at all. Reads the linked
//                          real tournament's own already-computed standings
//                          (user_bracket / pickem_entry), filters to just
//                          this league's own members, re-ranks 1..N among
//                          that subset, and records season_week_tournament_
//                          result rows via the week's placement_points_config
//                          (or the config's marquee_tournament default).
//                          Does NOT touch wins/losses - a standings-points
//                          addend, not a game.
//   conference/nationals - NOT head-to-head. Every member plays their own
//                          roster independently this week - same lineup
//                          scoring function as head_to_head (all of a
//                          wrestler's matches count, closer to pick'em
//                          scoring), but no matchup/win-loss at all. Members
//                          are then ranked against each other by their own
//                          week's lineup.points, and awarded season-standings
//                          points from a placement table - same mechanism as
//                          marquee weeks, just roster-ranked instead of
//                          reading an external tournament leaderboard. These
//                          weeks counting for more than a regular week is
//                          entirely a function of their own placement
//                          table's values (e.g. nationals' 1st-place value
//                          being much higher than a regular week's) - there
//                          is no separate weight_multiplier field anymore.
//
// Still not built: the actual season-standings/champion GET that sums this
// ledger (apis/league/leagues_standings_GET.xs).
//
// Bye weeks (odd member count, matchup.away_membership_id null) default to
// an automatic win for the home side at 0 away points (confirmed 2026-07-22).
task score_league_weeks {
  stack {
    var $now {
      value = now
    }

    // --- Lock weeks whose start time has passed ---
    db.query season_week {
      where = ($db.season_week.status == "upcoming" || $db.season_week.status == "open") && $db.season_week.starts_at <= $now
      return = {type: "list"}
    } as $weeks_to_lock

    var $locked_count {
      value = 0
    }

    foreach ($weeks_to_lock) {
      each as $w {
        try_catch {
          try {
            db.edit season_week {
              field_name = "id"
              field_value = $w.id
              data = {status: "locked"}
            } as $updated_week

            math.add $locked_count {
              value = 1
            }
          }

          catch {
            debug.log {
              value = {season_week_id: $w.id, error: $error.message}
            }
          }
        }
      }
    }

    // --- Score weeks whose end time (+ settle buffer) has passed ---
    // 6-hour settle buffer for late-arriving results
    var $settle_buffer_ms {
      value = 21600000
    }

    var $score_cutoff {
      value = $now - $settle_buffer_ms
    }

    db.query season_week {
      where = $db.season_week.status == "locked" && $db.season_week.ends_at <= $score_cutoff
      return = {type: "list"}
    } as $weeks_to_score

    function.run get_default_league_config {
      input = {}
    } as $default_config

    var $scored_count {
      value = 0
    }

    var $head_to_head_scored {
      value = 0
    }

    var $marquee_scored {
      value = 0
    }

    var $postseason_scored {
      value = 0
    }

    foreach ($weeks_to_score) {
      each as $week {
        try_catch {
          try {
            db.get season {
              field_name = "id"
              field_value = $week.season_id
            } as $season

            var $season_year {
              value = 0
            }

            conditional {
              if ($season != null) {
                var.update $season_year {
                  value = $season.year
                }
              }
            }

            db.query league {
              where = $db.league.season_id == $week.season_id
              return = {type: "list"}
            } as $leagues_in_season

            foreach ($leagues_in_season) {
              each as $league {
                try_catch {
                  try {
                    // Overlay this league's scoring_config (whole sub-object
                    // per key) on top of the shared default config
                    var $league_overrides {
                      value = {}
                    }

                    conditional {
                      if ($league.scoring_config != null) {
                        var.update $league_overrides {
                          value = $league.scoring_config
                        }
                      }
                    }

                    var $victory_points {
                      value = $league_overrides|get:"victory_points":$default_config.victory_points
                    }

                    var $medal_bonus {
                      value = $league_overrides|get:"medal_bonus":$default_config.medal_bonus
                    }

                    var $opponent_multipliers {
                      value = $league_overrides|get:"opponent_multipliers":$default_config.opponent_multipliers
                    }

                    // Flat points a head_to_head result adds to the season
                    // standings ledger, and the fallback rank->points tables
                    // used when a week's own placement_points_config is null
                    // - both feed the same unified season_week_tournament_
                    // result ledger every week type writes into.
                    var $h2h_points {
                      value = $league_overrides|get:"head_to_head_result_points":$default_config.head_to_head_result_points
                    }

                    var $placement_defaults {
                      value = $league_overrides|get:"placement_points_defaults":$default_config.placement_points_defaults
                    }

                    conditional {
                      if ($week.week_type == "head_to_head" || $week.week_type == "conference" || $week.week_type == "nationals") {
                        function.run score_league_lineups_for_week {
                          input = {
                            league_id      : $league.id
                            season_week_id : $week.id
                            week_starts_at : $week.starts_at
                            week_ends_at   : $week.ends_at
                            season_year    : $season_year
                            victory_points : $victory_points
                            medal_bonus    : $medal_bonus
                            opponent_multipliers: $opponent_multipliers
                          }
                        } as $lineup_result

                        conditional {
                          if ($week.week_type == "head_to_head") {
                            db.query matchup {
                              where = $db.matchup.league_id == $league.id && $db.matchup.season_week_id == $week.id
                              return = {type: "list"}
                            } as $matchups

                            foreach ($matchups) {
                              each as $m {
                                try_catch {
                                  try {
                                    db.query lineup {
                                      where = $db.lineup.league_id == $league.id && $db.lineup.membership_id == $m.home_membership_id && $db.lineup.season_week_id == $week.id
                                      return = {type: "single"}
                                    } as $home_lineup

                                    var $home_points {
                                      value = 0
                                    }

                                    conditional {
                                      if ($home_lineup != null) {
                                        var.update $home_points {
                                          value = $home_lineup.points
                                        }
                                      }
                                    }

                                    var $away_points {
                                      value = 0
                                    }

                                    conditional {
                                      if ($m.away_membership_id != null) {
                                        db.query lineup {
                                          where = $db.lineup.league_id == $league.id && $db.lineup.membership_id == $m.away_membership_id && $db.lineup.season_week_id == $week.id
                                          return = {type: "single"}
                                        } as $away_lineup

                                        conditional {
                                          if ($away_lineup != null) {
                                            var.update $away_points {
                                              value = $away_lineup.points
                                            }
                                          }
                                        }
                                      }
                                    }

                                    var $result {
                                      value = "tie"
                                    }

                                    conditional {
                                      if ($m.away_membership_id == null) {
                                        var.update $result {
                                          value = "home"
                                        }
                                      }
                                      elseif ($home_points > $away_points) {
                                        var.update $result {
                                          value = "home"
                                        }
                                      }
                                      elseif ($away_points > $home_points) {
                                        var.update $result {
                                          value = "away"
                                        }
                                      }
                                    }

                                    db.edit matchup {
                                      field_name = "id"
                                      field_value = $m.id
                                      data = {
                                        home_points: $home_points
                                        away_points: $away_points
                                        result     : $result
                                        status     : "complete"
                                      }
                                    } as $updated_matchup

                                    db.get league_membership {
                                      field_name = "id"
                                      field_value = $m.home_membership_id
                                    } as $home_member

                                    conditional {
                                      if ($home_member != null) {
                                        var $home_wins {
                                          value = $home_member.wins
                                        }

                                        var $home_losses {
                                          value = $home_member.losses
                                        }

                                        conditional {
                                          if ($result == "home") {
                                            math.add $home_wins { value = 1 }
                                          }
                                          elseif ($result == "away") {
                                            math.add $home_losses { value = 1 }
                                          }
                                        }

                                        db.edit league_membership {
                                          field_name = "id"
                                          field_value = $home_member.id
                                          data = {
                                            wins          : $home_wins
                                            losses        : $home_losses
                                            points_for    : $home_member.points_for + $home_points
                                            points_against: $home_member.points_against + $away_points
                                          }
                                        } as $updated_home_member
                                      }
                                    }

                                    conditional {
                                      if ($m.away_membership_id != null) {
                                        db.get league_membership {
                                          field_name = "id"
                                          field_value = $m.away_membership_id
                                        } as $away_member

                                        conditional {
                                          if ($away_member != null) {
                                            var $away_wins {
                                              value = $away_member.wins
                                            }

                                            var $away_losses {
                                              value = $away_member.losses
                                            }

                                            conditional {
                                              if ($result == "away") {
                                                math.add $away_wins { value = 1 }
                                              }
                                              elseif ($result == "home") {
                                                math.add $away_losses { value = 1 }
                                              }
                                            }

                                            db.edit league_membership {
                                              field_name = "id"
                                              field_value = $away_member.id
                                              data = {
                                                wins          : $away_wins
                                                losses        : $away_losses
                                                points_for    : $away_member.points_for + $away_points
                                                points_against: $away_member.points_against + $home_points
                                              }
                                            } as $updated_away_member
                                          }
                                        }
                                      }
                                    }

                                    // Convert this head_to_head result into flat
                                    // points for the SAME unified season-long
                                    // ledger every week type writes into (see
                                    // season_week_tournament_result) - a
                                    // win/loss record alone can't be summed
                                    // against marquee/conference/nationals'
                                    // points-shaped contributions.
                                    var $home_result_key {
                                      value = "tie"
                                    }

                                    conditional {
                                      if ($result == "home") {
                                        var.update $home_result_key {
                                          value = "win"
                                        }
                                      }
                                      elseif ($result == "away") {
                                        var.update $home_result_key {
                                          value = "loss"
                                        }
                                      }
                                    }

                                    var $home_rank {
                                      value = 1
                                    }

                                    conditional {
                                      if ($home_result_key == "loss") {
                                        var.update $home_rank {
                                          value = 2
                                        }
                                      }
                                    }

                                    db.add season_week_tournament_result {
                                      data = {
                                        created_at    : now
                                        league_id     : $league.id
                                        season_week_id: $week.id
                                        membership_id : $m.home_membership_id
                                        rank_in_league: $home_rank
                                        awarded_points: $h2h_points|get:$home_result_key:0
                                      }
                                    } as $home_swtr

                                    conditional {
                                      if ($m.away_membership_id != null) {
                                        var $away_result_key {
                                          value = "tie"
                                        }

                                        conditional {
                                          if ($result == "away") {
                                            var.update $away_result_key {
                                              value = "win"
                                            }
                                          }
                                          elseif ($result == "home") {
                                            var.update $away_result_key {
                                              value = "loss"
                                            }
                                          }
                                        }

                                        var $away_rank {
                                          value = 1
                                        }

                                        conditional {
                                          if ($away_result_key == "loss") {
                                            var.update $away_rank {
                                              value = 2
                                            }
                                          }
                                        }

                                        db.add season_week_tournament_result {
                                          data = {
                                            created_at    : now
                                            league_id     : $league.id
                                            season_week_id: $week.id
                                            membership_id : $m.away_membership_id
                                            rank_in_league: $away_rank
                                            awarded_points: $h2h_points|get:$away_result_key:0
                                          }
                                        } as $away_swtr
                                      }
                                    }
                                  }

                                  catch {
                                    debug.log {
                                      value = {matchup_id: $m.id, error: $error.message}
                                    }
                                  }
                                }
                              }
                            }

                            math.add $head_to_head_scored { value = 1 }
                          }
                          else {
                            // Conference/nationals: NOT head-to-head - every
                            // member played their own roster independently
                            // this week (score_league_lineups_for_week already
                            // ran above, same averaging math as head_to_head).
                            // Rank members by their own week score and award
                            // season-standings points from a placement table,
                            // same shape/mechanism as marquee weeks below -
                            // this is what lets conference/nationals count for
                            // more than a regular week, entirely through this
                            // table's own values (no separate weight field).
                            db.query lineup {
                              where = $db.lineup.league_id == $league.id && $db.lineup.season_week_id == $week.id
                              return = {type: "list"}
                            } as $week_lineups

                            var $postseason_score_list {
                              value = []
                            }

                            foreach ($week_lineups) {
                              each as $ln {
                                array.push $postseason_score_list {
                                  value = {membership_id: $ln.membership_id, score: $ln.points}
                                }
                              }
                            }

                            var $sorted_postseason_scores {
                              value = $postseason_score_list|sort:"score":"number"|reverse
                            }

                            var $postseason_placement_cfg {
                              value = $placement_defaults|get:$week.week_type:{}
                            }

                            conditional {
                              if ($week.placement_points_config != null) {
                                var.update $postseason_placement_cfg {
                                  value = $week.placement_points_config
                                }
                              }
                            }

                            var $postseason_rank_counter {
                              value = 0
                            }

                            foreach ($sorted_postseason_scores) {
                              each as $pentry {
                                try_catch {
                                  try {
                                    math.add $postseason_rank_counter { value = 1 }

                                    var $postseason_placement_key {
                                      value = $postseason_rank_counter|to_text
                                    }

                                    // NOT the nested |get:key:($cfg|get:"default":0)
                                    // pattern - a real XanoScript |get: engine
                                    // bug (confirmed 2026-07-22) returns null
                                    // instead of the default when that
                                    // default is 0 and the key is missing.
                                    var $postseason_awarded {
                                      value = 0
                                    }

                                    conditional {
                                      if ($postseason_placement_cfg|has:$postseason_placement_key) {
                                        var.update $postseason_awarded {
                                          value = $postseason_placement_cfg|get:$postseason_placement_key:0
                                        }
                                      }
                                      elseif ($postseason_placement_cfg|has:"default") {
                                        var.update $postseason_awarded {
                                          value = $postseason_placement_cfg|get:"default":0
                                        }
                                      }
                                    }

                                    db.add season_week_tournament_result {
                                      data = {
                                        created_at    : now
                                        league_id     : $league.id
                                        season_week_id: $week.id
                                        membership_id : $pentry.membership_id
                                        rank_in_league: $postseason_rank_counter
                                        awarded_points: $postseason_awarded
                                      }
                                    } as $postseason_swtr
                                  }

                                  catch {
                                    debug.log {
                                      value = {league_id: $league.id, season_week_id: $week.id, membership_id: $pentry.membership_id, error: $error.message}
                                    }
                                  }
                                }
                              }
                            }

                            math.add $postseason_scored { value = 1 }
                          }
                        }
                      }
                      elseif ($week.week_type == "marquee_tournament" && $week.linked_tournament_id != null) {
                        var $member_scores {
                          value = {}
                        }

                        conditional {
                          if ($week.tournament_game_mode == "bracket" || $week.tournament_game_mode == "bracket_pickem") {
                            db.query user_bracket {
                              where = $db.user_bracket.tournament_id == $week.linked_tournament_id
                              return = {type: "list"}
                            } as $bracket_entries

                            foreach ($bracket_entries) {
                              each as $entry {
                                db.query league_membership {
                                  where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $entry.user_id
                                  return = {type: "single"}
                                } as $member

                                conditional {
                                  if ($member != null) {
                                    var $existing_score {
                                      value = $member_scores|get:($member.id|to_text):0
                                    }

                                    var $entry_points {
                                      value = 0
                                    }

                                    conditional {
                                      if ($entry.total_points != null) {
                                        var.update $entry_points {
                                          value = $entry.total_points
                                        }
                                      }
                                    }

                                    var.update $member_scores {
                                      value = $member_scores|set:($member.id|to_text):($existing_score + $entry_points)
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }

                        conditional {
                          if ($week.tournament_game_mode == "pickem" || $week.tournament_game_mode == "bracket_pickem") {
                            db.query pickem_entry {
                              where = $db.pickem_entry.tournament_id == $week.linked_tournament_id
                              return = {type: "list"}
                            } as $pickem_entries

                            foreach ($pickem_entries) {
                              each as $entry {
                                db.query league_membership {
                                  where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $entry.user_id
                                  return = {type: "single"}
                                } as $member

                                conditional {
                                  if ($member != null) {
                                    var $existing_score {
                                      value = $member_scores|get:($member.id|to_text):0
                                    }

                                    var $entry_points {
                                      value = 0
                                    }

                                    conditional {
                                      if ($entry.total_points != null) {
                                        var.update $entry_points {
                                          value = $entry.total_points
                                        }
                                      }
                                    }

                                    var.update $member_scores {
                                      value = $member_scores|set:($member.id|to_text):($existing_score + $entry_points)
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }

                        var $score_list {
                          value = []
                        }

                        var $member_keys {
                          value = $member_scores|keys
                        }

                        foreach ($member_keys) {
                          each as $mkey {
                            array.push $score_list {
                              value = {membership_id: ($mkey|to_int), score: $member_scores[$mkey]}
                            }
                          }
                        }

                        var $sorted_scores {
                          value = $score_list|sort:"score":"number"|reverse
                        }

                        var $placement_cfg {
                          value = {}
                        }

                        conditional {
                          if ($week.placement_points_config != null) {
                            var.update $placement_cfg {
                              value = $week.placement_points_config
                            }
                          }
                        }

                        var $rank_counter {
                          value = 0
                        }

                        foreach ($sorted_scores) {
                          each as $entry {
                            math.add $rank_counter { value = 1 }

                            var $placement_key {
                              value = $rank_counter|to_text
                            }

                            // NOT the nested |get:key:($cfg|get:"default":0)
                            // pattern - a real XanoScript |get: engine bug
                            // (confirmed 2026-07-22) returns null instead of
                            // the default when that default is 0 and the key
                            // is missing.
                            var $awarded {
                              value = 0
                            }

                            conditional {
                              if ($placement_cfg|has:$placement_key) {
                                var.update $awarded {
                                  value = $placement_cfg|get:$placement_key:0
                                }
                              }
                              elseif ($placement_cfg|has:"default") {
                                var.update $awarded {
                                  value = $placement_cfg|get:"default":0
                                }
                              }
                            }

                            db.add season_week_tournament_result {
                              data = {
                                created_at    : now
                                league_id     : $league.id
                                season_week_id: $week.id
                                membership_id : $entry.membership_id
                                rank_in_league: $rank_counter
                                awarded_points: $awarded
                              }
                            } as $swtr
                          }
                        }

                        math.add $marquee_scored { value = 1 }
                      }
                    }

                    // Notify active members that this league's part of the
                    // week is scored
                    db.query league_membership {
                        where = $db.league_membership.league_id == $league.id && $db.league_membership.status == "active"
                        return = {type: "list"}
                      } as $active_members

                      foreach ($active_members) {
                        each as $member {
                          try_catch {
                            try {
                              function.run notify {
                                input = {
                                  user_id: $member.user_id
                                  type   : "week_scored"
                                  title  : "Week " ~ ($week.week_number|to_text) ~ " scored"
                                  body   : $league.name ~ "'s results are in for this week."
                                  data   : {league_id: $league.id, season_week_id: $week.id}
                                }
                              } as $notify_result
                            }

                            catch {
                              debug.log {
                                value = {league_id: $league.id, member_id: $member.id, error: $error.message}
                              }
                            }
                          }
                        }
                      }
                    }

                  catch {
                    debug.log {
                      value = {league_id: $league.id, season_week_id: $week.id, error: $error.message}
                    }
                  }
                }
              }
            }

            db.edit season_week {
              field_name = "id"
              field_value = $week.id
              data = {status: "complete"}
            } as $completed_week

            math.add $scored_count {
              value = 1
            }
          }

          catch {
            debug.log {
              value = {season_week_id: $week.id, error: $error.message}
            }
          }
        }
      }
    }

    debug.log {
      value = {
        weeks_locked      : $locked_count
        weeks_scored      : $scored_count
        head_to_head_scored: $head_to_head_scored
        marquee_scored    : $marquee_scored
        postseason_scored : $postseason_scored
      }
    }
  }

  schedule = [{starts_on: 2026-07-22 00:00:00+0000, freq: 300}]
  guid = "zTaBenng2eT7SncIujNJ5jNBtcE"
}

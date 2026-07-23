// Canonical wrestler profile: identity, team history (with season links),
// overall + season-by-season record, and full match history. Public, same
// as the rest of the results explorer - no auth needed to browse historical
// results. wrestler_match_history has no season column of its own, so each
// match's season is derived from occurred_at against fixed academic-year
// boundaries (Aug 1 - Jul 31) covering the 4 scraped seasons.
query "results/wrestlers/{id}" verb=GET {
  api_group = "brackets"

  input {
    int id
  }

  stack {
    db.get canonical_wrestler {
      field_name = "id"
      field_value = $input.id
    } as $wrestler

    precondition ($wrestler != null) {
      error_type = "notfound"
      error = "Wrestler not found."
    }

    var $current_team {
      value = null
    }

    conditional {
      if ($wrestler.current_team_id != null) {
        db.get canonical_team {
          field_name = "id"
          field_value = $wrestler.current_team_id
        } as $ct

        conditional {
          if ($ct != null) {
            var.update $current_team {
              value = {id: $ct.id, name: $ct.name}
            }
          }
        }
      }
    }

    // Team history, oldest season first
    db.query canonical_wrestler_team {
      where = $db.canonical_wrestler_team.canonical_wrestler_id == $input.id
      sort = {canonical_wrestler_team.season_label: "asc"}
      return = {type: "list"}
    } as $links

    // Small, cheap table (79 rows) - fetch all rather than filtering by a
    // dynamic id list, which isn't a supported where-clause shape here.
    db.query canonical_team {
      return = {type: "list"}
    } as $teams

    var $team_name_map {
      value = {}
    }

    foreach ($teams) {
      each as $t {
        var.update $team_name_map {
          value = $team_name_map|set:$t.id:$t.name
        }
      }
    }

    var $team_history {
      value = []
    }

    foreach ($links) {
      each as $l {
        array.push $team_history {
          value = {
            team_id     : $l.canonical_team_id
            team_name   : $team_name_map[$l.canonical_team_id]
            season_label: $l.season_label
            match_count : $l.match_count
          }
        }
      }
    }

    // All matches (winner or loser side), newest first
    db.query wrestler_match_history {
      where = ($db.wrestler_match_history.winner_canonical_wrestler_id == $input.id) || ($db.wrestler_match_history.loser_canonical_wrestler_id == $input.id)
      sort = {wrestler_match_history.occurred_at: "desc"}
      return = {type: "list"}
    } as $matches

    var $season_bounds {
      value = [
        {label: "2022-23", start: 1659312000000, end: 1690847999000}
        {label: "2023-24", start: 1690848000000, end: 1722470399000}
        {label: "2024-25", start: 1722470400000, end: 1754006399000}
        {label: "2025-26", start: 1754006400000, end: 1785628799000}
      ]
    }

    var $overall_wins { value = 0 }
    var $overall_losses { value = 0 }
    var $overall_win_decision { value = 0 }
    var $overall_win_major { value = 0 }
    var $overall_win_tech_fall { value = 0 }
    var $overall_win_fall { value = 0 }
    var $overall_win_other { value = 0 }
    var $overall_loss_decision { value = 0 }
    var $overall_loss_major { value = 0 }
    var $overall_loss_tech_fall { value = 0 }
    var $overall_loss_fall { value = 0 }
    var $overall_loss_other { value = 0 }

    // Each of these is a single-purpose {season_label: count} map - see
    // functions/utils/bump_season_map.xs for why this is 12 separate flat
    // maps rather than one map of multi-key breakdown objects.
    var $season_wins { value = {} }
    var $season_losses { value = {} }
    var $season_win_decision { value = {} }
    var $season_win_major { value = {} }
    var $season_win_tech_fall { value = {} }
    var $season_win_fall { value = {} }
    var $season_win_other { value = {} }
    var $season_loss_decision { value = {} }
    var $season_loss_major { value = {} }
    var $season_loss_tech_fall { value = {} }
    var $season_loss_fall { value = {} }
    var $season_loss_other { value = {} }

    var $match_list { value = [] }

    foreach ($matches) {
      each as $m {
        var $is_winner {
          value = $m.winner_canonical_wrestler_id == $input.id
        }

        var $season_label {
          value = null
        }

        foreach ($season_bounds) {
          each as $sb {
            conditional {
              if ($m.occurred_at >= $sb.start && $m.occurred_at <= $sb.end) {
                var.update $season_label {
                  value = $sb.label
                }
              }
            }
          }
        }

        function.run normalize_victory_type {
          input = {raw: $m.victory_type}
        } as $vtype

        var $vtype_key { value = "other" }

        conditional {
          if ($vtype == "decision") {
            var.update $vtype_key { value = "decision" }
          }
          elseif ($vtype == "major") {
            var.update $vtype_key { value = "major" }
          }
          elseif ($vtype == "tech_fall") {
            var.update $vtype_key { value = "tech_fall" }
          }
          elseif ($vtype == "fall") {
            var.update $vtype_key { value = "fall" }
          }
        }

        conditional {
          if ($is_winner) {
            math.add $overall_wins { value = 1 }

            conditional {
              if ($season_label != null) {
                function.run bump_season_map {
                  input = {map: $season_wins, season_label: $season_label}
                } as $season_wins_next
                var.update $season_wins { value = $season_wins_next }
              }
            }

            conditional {
              if ($vtype_key == "decision") {
                math.add $overall_win_decision { value = 1 }
                conditional {
                  if ($season_label != null) {
                    function.run bump_season_map {
                      input = {map: $season_win_decision, season_label: $season_label}
                    } as $season_win_decision_next
                    var.update $season_win_decision { value = $season_win_decision_next }
                  }
                }
              }
              elseif ($vtype_key == "major") {
                math.add $overall_win_major { value = 1 }
                conditional {
                  if ($season_label != null) {
                    function.run bump_season_map {
                      input = {map: $season_win_major, season_label: $season_label}
                    } as $season_win_major_next
                    var.update $season_win_major { value = $season_win_major_next }
                  }
                }
              }
              elseif ($vtype_key == "tech_fall") {
                math.add $overall_win_tech_fall { value = 1 }
                conditional {
                  if ($season_label != null) {
                    function.run bump_season_map {
                      input = {map: $season_win_tech_fall, season_label: $season_label}
                    } as $season_win_tech_fall_next
                    var.update $season_win_tech_fall { value = $season_win_tech_fall_next }
                  }
                }
              }
              elseif ($vtype_key == "fall") {
                math.add $overall_win_fall { value = 1 }
                conditional {
                  if ($season_label != null) {
                    function.run bump_season_map {
                      input = {map: $season_win_fall, season_label: $season_label}
                    } as $season_win_fall_next
                    var.update $season_win_fall { value = $season_win_fall_next }
                  }
                }
              }
              else {
                math.add $overall_win_other { value = 1 }
                conditional {
                  if ($season_label != null) {
                    function.run bump_season_map {
                      input = {map: $season_win_other, season_label: $season_label}
                    } as $season_win_other_next
                    var.update $season_win_other { value = $season_win_other_next }
                  }
                }
              }
            }
          }
          else {
            math.add $overall_losses { value = 1 }

            conditional {
              if ($season_label != null) {
                function.run bump_season_map {
                  input = {map: $season_losses, season_label: $season_label}
                } as $season_losses_next
                var.update $season_losses { value = $season_losses_next }
              }
            }

            conditional {
              if ($vtype_key == "decision") {
                math.add $overall_loss_decision { value = 1 }
                conditional {
                  if ($season_label != null) {
                    function.run bump_season_map {
                      input = {map: $season_loss_decision, season_label: $season_label}
                    } as $season_loss_decision_next
                    var.update $season_loss_decision { value = $season_loss_decision_next }
                  }
                }
              }
              elseif ($vtype_key == "major") {
                math.add $overall_loss_major { value = 1 }
                conditional {
                  if ($season_label != null) {
                    function.run bump_season_map {
                      input = {map: $season_loss_major, season_label: $season_label}
                    } as $season_loss_major_next
                    var.update $season_loss_major { value = $season_loss_major_next }
                  }
                }
              }
              elseif ($vtype_key == "tech_fall") {
                math.add $overall_loss_tech_fall { value = 1 }
                conditional {
                  if ($season_label != null) {
                    function.run bump_season_map {
                      input = {map: $season_loss_tech_fall, season_label: $season_label}
                    } as $season_loss_tech_fall_next
                    var.update $season_loss_tech_fall { value = $season_loss_tech_fall_next }
                  }
                }
              }
              elseif ($vtype_key == "fall") {
                math.add $overall_loss_fall { value = 1 }
                conditional {
                  if ($season_label != null) {
                    function.run bump_season_map {
                      input = {map: $season_loss_fall, season_label: $season_label}
                    } as $season_loss_fall_next
                    var.update $season_loss_fall { value = $season_loss_fall_next }
                  }
                }
              }
              else {
                math.add $overall_loss_other { value = 1 }
                conditional {
                  if ($season_label != null) {
                    function.run bump_season_map {
                      input = {map: $season_loss_other, season_label: $season_label}
                    } as $season_loss_other_next
                    var.update $season_loss_other { value = $season_loss_other_next }
                  }
                }
              }
            }
          }
        }

        var $opponent_name { value = $m.winner_name_raw }
        var $opponent_school { value = $m.winner_school_raw }
        var $opponent_id { value = $m.winner_canonical_wrestler_id }

        conditional {
          if ($is_winner) {
            var.update $opponent_name { value = $m.loser_name_raw }
            var.update $opponent_school { value = $m.loser_school_raw }
            var.update $opponent_id { value = $m.loser_canonical_wrestler_id }
          }
        }

        array.push $match_list {
          value = {
            id               : $m.id
            season_label     : $season_label
            is_winner        : $is_winner
            opponent_name    : $opponent_name
            opponent_school  : $opponent_school
            opponent_id      : $opponent_id
            weight_class     : $m.weight_class
            victory_type     : $m.victory_type
            score            : $m.score
            time_seconds     : $m.time_seconds
            round_label      : $m.round_label
            event_name       : $m.event_name
            event_type       : $m.event_type
            occurred_at      : $m.occurred_at
          }
        }
      }
    }

    // Team name per season, from the roster-link history (a mid-season
    // transfer would only keep the last-linked team for that season - rare
    // edge case, not worth a multi-team-per-season row shape here).
    var $team_name_by_season { value = {} }

    foreach ($team_history) {
      each as $t {
        var.update $team_name_by_season {
          value = $team_name_by_season|set:$t.season_label:$t.team_name
        }
      }
    }

    function.run compute_bonus_pct {
      input = {wins: $overall_wins, win_major: $overall_win_major, win_tech_fall: $overall_win_tech_fall, win_fall: $overall_win_fall}
    } as $overall_bonus_pct

    // One combined row per season the wrestler has ANY record of (a team
    // link, match results, or both) - merges what used to be two separate
    // "Team History" and "Season Records" sections into a single table.
    var $season_rows { value = [] }

    foreach ($season_bounds) {
      each as $sb {
        var $has_team { value = ($team_name_by_season|has:$sb.label) }
        var $has_matches { value = ($season_wins|has:$sb.label) || ($season_losses|has:$sb.label) }

        conditional {
          if ($has_team || $has_matches) {
            var $wins { value = 0 }
            var $losses { value = 0 }
            var $win_decision { value = 0 }
            var $win_major { value = 0 }
            var $win_tech_fall { value = 0 }
            var $win_fall { value = 0 }
            var $win_other { value = 0 }
            var $loss_decision { value = 0 }
            var $loss_major { value = 0 }
            var $loss_tech_fall { value = 0 }
            var $loss_fall { value = 0 }
            var $loss_other { value = 0 }

            conditional {
              if ($season_wins|has:$sb.label) {
                var.update $wins { value = $season_wins[$sb.label] }
              }
            }
            conditional {
              if ($season_losses|has:$sb.label) {
                var.update $losses { value = $season_losses[$sb.label] }
              }
            }
            conditional {
              if ($season_win_decision|has:$sb.label) {
                var.update $win_decision { value = $season_win_decision[$sb.label] }
              }
            }
            conditional {
              if ($season_win_major|has:$sb.label) {
                var.update $win_major { value = $season_win_major[$sb.label] }
              }
            }
            conditional {
              if ($season_win_tech_fall|has:$sb.label) {
                var.update $win_tech_fall { value = $season_win_tech_fall[$sb.label] }
              }
            }
            conditional {
              if ($season_win_fall|has:$sb.label) {
                var.update $win_fall { value = $season_win_fall[$sb.label] }
              }
            }
            conditional {
              if ($season_win_other|has:$sb.label) {
                var.update $win_other { value = $season_win_other[$sb.label] }
              }
            }
            conditional {
              if ($season_loss_decision|has:$sb.label) {
                var.update $loss_decision { value = $season_loss_decision[$sb.label] }
              }
            }
            conditional {
              if ($season_loss_major|has:$sb.label) {
                var.update $loss_major { value = $season_loss_major[$sb.label] }
              }
            }
            conditional {
              if ($season_loss_tech_fall|has:$sb.label) {
                var.update $loss_tech_fall { value = $season_loss_tech_fall[$sb.label] }
              }
            }
            conditional {
              if ($season_loss_fall|has:$sb.label) {
                var.update $loss_fall { value = $season_loss_fall[$sb.label] }
              }
            }
            conditional {
              if ($season_loss_other|has:$sb.label) {
                var.update $loss_other { value = $season_loss_other[$sb.label] }
              }
            }

            function.run compute_bonus_pct {
              input = {wins: $wins, win_major: $win_major, win_tech_fall: $win_tech_fall, win_fall: $win_fall}
            } as $bonus_pct

            array.push $season_rows {
              value = {
                season_label: $sb.label
                team_name   : ($has_team ? $team_name_by_season[$sb.label] : null)
                wins        : $wins
                losses      : $losses
                bonus_pct   : $bonus_pct
                win_breakdown : {decision: $win_decision, major: $win_major, tech_fall: $win_tech_fall, fall: $win_fall, other: $win_other}
                loss_breakdown: {decision: $loss_decision, major: $loss_major, tech_fall: $loss_tech_fall, fall: $loss_fall, other: $loss_other}
              }
            }
          }
        }
      }
    }
  }

  response = {
    wrestler: {
      id              : $wrestler.id
      display_name    : $wrestler.display_name
      legal_first_name: $wrestler.legal_first_name
      legal_last_name : $wrestler.legal_last_name
      gender          : $wrestler.gender
      current_team    : $current_team
      profile_url     : $wrestler.profile_url
    }
    season_rows   : $season_rows
    overall_bonus_pct: $overall_bonus_pct
    overall_record: {wins: $overall_wins, losses: $overall_losses}
    matches       : $match_list
  }
  guid = "Jm4wSpXt7VqNzKbYrLo9DcF3hUe"
}

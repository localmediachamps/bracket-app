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
    var $season_records { value = {} }
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

        var $rec {
          value = {wins: 0, losses: 0}
        }

        conditional {
          if ($season_label != null && ($season_records|has:$season_label)) {
            var.update $rec {
              value = $season_records[$season_label]
            }
          }
        }

        conditional {
          if ($is_winner) {
            math.add $overall_wins { value = 1 }
            var.update $rec { value = $rec|set:"wins":$rec.wins + 1 }
          }
          else {
            math.add $overall_losses { value = 1 }
            var.update $rec { value = $rec|set:"losses":$rec.losses + 1 }
          }
        }

        conditional {
          if ($season_label != null) {
            var.update $season_records {
              value = $season_records|set:$season_label:$rec
            }
          }
        }

        var $opponent_name { value = $m.winner_name_raw }
        var $opponent_school { value = $m.winner_school_raw }

        conditional {
          if ($is_winner) {
            var.update $opponent_name { value = $m.loser_name_raw }
            var.update $opponent_school { value = $m.loser_school_raw }
          }
        }

        array.push $match_list {
          value = {
            id               : $m.id
            season_label     : $season_label
            is_winner        : $is_winner
            opponent_name    : $opponent_name
            opponent_school  : $opponent_school
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

    var $season_records_out {
      value = []
    }

    foreach ($season_bounds) {
      each as $sb {
        conditional {
          if ($season_records|has:$sb.label) {
            array.push $season_records_out {
              value = {
                season_label: $sb.label
                wins        : $season_records[$sb.label].wins
                losses      : $season_records[$sb.label].losses
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
    }
    team_history  : $team_history
    overall_record: {wins: $overall_wins, losses: $overall_losses}
    season_records: $season_records_out
    matches       : $match_list
  }
  guid = "Jm4wSpXt7VqNzKbYrLo9DcF3hUe"
}

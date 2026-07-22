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
              }
            }
          }
        }
      }
    }

    // Group roster links by season, newest season first
    var $season_order {
      value = ["2025-26", "2024-25", "2023-24", "2022-23"]
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

        var $bounds {
          value = $season_bounds[$l.season_label]
        }

        conditional {
          if ($bounds != null) {
            db.query wrestler_match_history {
              where = (($db.wrestler_match_history.winner_canonical_wrestler_id == $l.canonical_wrestler_id) || ($db.wrestler_match_history.loser_canonical_wrestler_id == $l.canonical_wrestler_id)) && ($db.wrestler_match_history.occurred_at >= $bounds.start) && ($db.wrestler_match_history.occurred_at <= $bounds.end)
              return = {type: "single"}
            } as $sample_match

            conditional {
              if ($sample_match != null) {
                var.update $weight_class {
                  value = $sample_match.weight_class
                }
              }
            }
          }
        }

        array.push $season_list {
          value = {
            wrestler_id : $l.canonical_wrestler_id
            display_name: $wrestler_name_map[$l.canonical_wrestler_id]
            weight_class: $weight_class
            match_count : $l.match_count
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

            array.push $roster_out {
              value = {
                season_label: $season
                wrestlers   : $sorted
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
    }
    roster  : $roster_out
    schedule: []
  }
  guid = "Nq7tXpZv5RwCmYkLbFo2DjH6uAe"
}

// Directory of all D1 teams (canonical_team) for the Teams browser - a
// second pathway to team/wrestler profiles alongside clicking through
// Results. Public, same as the rest of the results explorer.
query "results/teams" verb=GET {
  api_group = "brackets"

  input {
  }

  stack {
    db.query canonical_team {
      sort = {canonical_team.name: "asc"}
      return = {type: "list"}
    } as $teams

    db.query canonical_wrestler_team {
      return = {type: "list"}
    } as $links

    // Roster size per team, most-recent season only (a rough "current
    // roster" count for the directory card - full history is on the team's
    // own profile page).
    var $latest_season {
      value = "2025-26"
    }

    var $roster_counts {
      value = {}
    }

    foreach ($links) {
      each as $l {
        conditional {
          if ($l.season_label == $latest_season) {
            var $count {
              value = 0
            }

            conditional {
              if ($roster_counts|has:$l.canonical_team_id) {
                var.update $count {
                  value = $roster_counts[$l.canonical_team_id]
                }
              }
            }

            math.add $count { value = 1 }

            var.update $roster_counts {
              value = $roster_counts|set:$l.canonical_team_id:$count
            }
          }
        }
      }
    }

    var $out {
      value = []
    }

    foreach ($teams) {
      each as $t {
        var $roster_count {
          value = 0
        }

        conditional {
          if ($roster_counts|has:$t.id) {
            var.update $roster_count {
              value = $roster_counts[$t.id]
            }
          }
        }

        array.push $out {
          value = {
            id           : $t.id
            name         : $t.name
            state        : $t.state
            conference   : $t.conference
            roster_count : $roster_count
          }
        }
      }
    }
  }

  response = {
    teams: $out
  }
  guid = "Kp5rWnZs3TvBqYmLxDo8FjC4hUe"
}

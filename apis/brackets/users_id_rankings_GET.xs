// Public display of a user's personal wrestler rankings (the "show off your
// point of view" feature) - grouped by weight class, most recent
// season_year the user has any rankings for (or a specific one via the
// optional param). No auth - this is meant to be shown on the public
// profile page same as public submissions.
query "users/{id}/rankings" verb=GET {
  api_group = "brackets"

  input {
    int id
    int? season_year?
  }

  stack {
    db.query user_wrestler_ranking {
      where = $db.user_wrestler_ranking.user_id == $input.id
      return = {type: "list"}
    } as $all_rows

    var $target_year {
      value = $input.season_year
    }

    conditional {
      if ($target_year == null) {
        var $best_year {
          value = 0
        }

        foreach ($all_rows) {
          each as $r {
            conditional {
              if ($r.season_year > $best_year) {
                var.update $best_year {
                  value = $r.season_year
                }
              }
            }
          }
        }

        var.update $target_year {
          value = $best_year
        }
      }
    }

    var $rows {
      value = []
    }

    foreach ($all_rows) {
      each as $r {
        conditional {
          if ($r.season_year == $target_year) {
            array.push $rows {
              value = $r
            }
          }
        }
      }
    }

    var $by_weight {
      value = {}
    }

    foreach ($rows) {
      each as $r {
        db.get canonical_wrestler {
          field_name = "id"
          field_value = $r.canonical_wrestler_id
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

        var $wkey {
          value = ($r.weight|to_text)
        }

        var $list {
          value = []
        }

        conditional {
          if ($by_weight|has:$wkey) {
            var.update $list {
              value = $by_weight[$wkey]
            }
          }
        }

        array.push $list {
          value = {
            rank        : $r.rank
            display_name: $w|get:"display_name":null
            team_name   : $team_name
          }
        }

        var.update $by_weight {
          value = $by_weight|set:$wkey:$list
        }
      }
    }

    var $weight_keys {
      value = ($by_weight|keys)
    }

    var $out {
      value = []
    }

    foreach ($weight_keys) {
      each as $wk {
        var $sorted_entries {
          value = ($by_weight[$wk])|sort:"rank":"number"
        }

        array.push $out {
          value = {weight: ($wk|to_int), entries: $sorted_entries}
        }
      }
    }

    var $sorted_out {
      value = $out|sort:"weight":"number"
    }
  }

  response = {
    season_year: $target_year
    weights    : $sorted_out
  }
  guid = "K5vTn8ZqRs3YcWpBo7HbFd9GkLm2"
}

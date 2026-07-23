// Season stat-leader boards (most wins/pins/tech-falls, fastest falls,
// highest-scoring matches) - reads the row precomputed by
// tasks/compute_season_stat_leaders.xs. Public, same as the rest of the
// results explorer. No season_label input means "most recent computed
// season". available_seasons lets the frontend build a season switcher
// without a separate request.
query "results/stat-leaders" verb=GET {
  api_group = "brackets"

  input {
    text? season_label? filters=trim
  }

  stack {
    db.query season_stat_leaders {
      sort = {season_stat_leaders.season_label: "desc"}
      return = {type: "list"}
    } as $all_rows

    var $available_seasons { value = [] }

    foreach ($all_rows) {
      each as $r {
        array.push $available_seasons {
          value = $r.season_label
        }
      }
    }

    var $target_label { value = $input.season_label }

    conditional {
      if ($target_label == null && ($all_rows|count) > 0) {
        var.update $target_label {
          value = ($all_rows|get:0:null)|get:"season_label":null
        }
      }
    }

    var $row { value = null }

    foreach ($all_rows) {
      each as $r {
        conditional {
          if ($r.season_label == $target_label) {
            var.update $row { value = $r }
          }
        }
      }
    }
  }

  response = {
    season_label           : $target_label
    available_seasons      : $available_seasons
    most_wins              : $row|get:"most_wins":[]
    most_pins              : $row|get:"most_pins":[]
    most_tech_falls        : $row|get:"most_tech_falls":[]
    fastest_falls          : $row|get:"fastest_falls":[]
    highest_scoring_matches: $row|get:"highest_scoring_matches":[]
    matches_considered     : $row|get:"matches_considered":0
    computed_at            : $row|get:"computed_at":null
  }
  guid = "s0BspjBpCe3fKoU4OZxuNCLOBM8"
}

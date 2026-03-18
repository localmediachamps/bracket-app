task "auto_score_tournament" {
  description = "Score all active and locked tournaments every 15 minutes. Calls score_user_bracket for every user bracket, then recomputes rank order by total_points."

  schedule = [{starts_on: 2026-03-17 00:00:00+0000, freq: 900}]

  history = "inherit"

  stack {
    debug.log {
      value = "auto_score_tournament: starting run"
    }

    db.query tournament {
      where  = $db.tournament.status == "active" || $db.tournament.status == "locked"
      return = {type: "list"}
    } as $tournaments

    var $total_scored {
      value = 0
    }

    foreach ($tournaments) {
      each as $tournament {
        db.query user_bracket {
          where  = $db.user_bracket.tournament_id == $tournament.id
          return = {type: "list"}
        } as $user_brackets

        foreach ($user_brackets) {
          each as $user_bracket {
            try_catch {
              try {
                function.run score_user_bracket {
                  input = {
                    user_bracket_id: $user_bracket.id
                    tournament_id  : $tournament.id
                  }
                } as $score_result

                math.add $total_scored {
                  value = 1
                }
              }

              catch {
                debug.log {
                  value = {user_bracket_id: $user_bracket.id, error: $error.message}
                }
              }
            }
          }
        }

        // Recompute ranks for this tournament
        db.query user_bracket {
          where  = $db.user_bracket.tournament_id == $tournament.id
          sort   = {user_bracket.total_points: "desc"}
          return = {type: "list"}
        } as $ranked_brackets

        var $rank {
          value = 1
        }

        foreach ($ranked_brackets) {
          each as $rb {
            db.edit user_bracket {
              field_name  = "id"
              field_value = $rb.id
              data        = {rank: $rank}
            } as $ranked_bracket

            math.add $rank {
              value = 1
            }
          }
        }
      }
    }

    debug.log {
      value = {total_scored: $total_scored}
    }
  }
}

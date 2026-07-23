// Public read of the Mat Savvy composite ranking for one weight+season -
// same shape and same top-12 head-to-head justification as admin/rankings,
// just without the admin gate, so any logged-in user can browse the
// official board (not just build their own at my/rankings).
query "rankings" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    int weight
    int season_year
  }

  stack {
    db.query wrestler_composite_ranking {
      where = ($db.wrestler_composite_ranking.weight == $input.weight) && ($db.wrestler_composite_ranking.season_year == $input.season_year)
      sort = {wrestler_composite_ranking.rank: "asc"}
      return = {type: "list"}
    } as $rows

    var $out {
      value = []
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

        array.push $out {
          value = {
            id                   : $r.id
            canonical_wrestler_id: $r.canonical_wrestler_id
            display_name         : $w|get:"display_name":null
            team_name            : $team_name
            rank                 : $r.rank
          }
        }
      }
    }

    // Top-12 head-to-head cross-reference - same "justifies the ranking"
    // evidence the admin editor shows, so the public board isn't just a
    // bare list of names.
    var $top12_lookup {
      value = {}
    }

    foreach ($out) {
      each as $o {
        conditional {
          if ($o.rank <= 12) {
            var.update $top12_lookup {
              value = $top12_lookup|set:($o.canonical_wrestler_id|to_text):{rank: $o.rank, display_name: $o.display_name}
            }
          }
        }
      }
    }

    var $out_with_h2h {
      value = []
    }

    foreach ($out) {
      each as $o {
        var $h2h {
          value = []
        }

        conditional {
          if ($o.rank <= 12) {
            db.query wrestler_match_history {
              where = ($db.wrestler_match_history.winner_canonical_wrestler_id == $o.canonical_wrestler_id) || ($db.wrestler_match_history.loser_canonical_wrestler_id == $o.canonical_wrestler_id)
              sort = {wrestler_match_history.occurred_at: "desc"}
              return = {type: "list"}
            } as $all_matches

            foreach ($all_matches) {
              each as $m {
                var $is_winner {
                  value = ($m.winner_canonical_wrestler_id == $o.canonical_wrestler_id)
                }

                var $opponent_id {
                  value = $m.loser_canonical_wrestler_id
                }

                conditional {
                  if ($is_winner == false) {
                    var.update $opponent_id {
                      value = $m.winner_canonical_wrestler_id
                    }
                  }
                }

                var $opponent_key {
                  value = ($opponent_id|to_text)
                }

                conditional {
                  if ($opponent_id != null && ($top12_lookup|has:$opponent_key) && $opponent_id != $o.canonical_wrestler_id) {
                    var $opponent_info {
                      value = $top12_lookup|get:$opponent_key:null
                    }

                    array.push $h2h {
                      value = {
                        is_winner      : $is_winner
                        opponent_id    : $opponent_id
                        opponent_name  : $opponent_info.display_name
                        opponent_rank  : $opponent_info.rank
                        victory_type   : $m.victory_type
                        score          : $m.score
                        event_name     : $m.event_name
                        occurred_at    : $m.occurred_at
                      }
                    }
                  }
                }
              }
            }
          }
        }

        array.push $out_with_h2h {
          value = $o|set:"head_to_head":$h2h
        }
      }
    }
  }

  response = {
    rankings: $out_with_h2h
  }
  guid = "V8mNs4RtLp6XcWo3HzYq9FbKgUj5"
}

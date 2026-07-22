// Compact career-record summary for one canonical_wrestler, computed over
// all of wrestler_match_history (not season-scoped - draft-time evaluation
// cares about the whole body of work, not just the current season). Shared
// by the draft pool browser and lineup/roster screens (fantasy league plan,
// Phase 7) so they show a consistent record rather than each computing it
// differently. Distinct from apis/brackets/results_wrestlers_id_GET.xs,
// which is season-by-season and match-by-match for the full profile page -
// this is the compact one-line version for list/grid contexts.
function get_wrestler_record_summary {
  input {
    int canonical_wrestler_id
  }

  stack {
    db.query wrestler_match_history {
      where = ($db.wrestler_match_history.winner_canonical_wrestler_id == $input.canonical_wrestler_id) || ($db.wrestler_match_history.loser_canonical_wrestler_id == $input.canonical_wrestler_id)
      return = {type: "list"}
    } as $matches

    var $wins {
      value = 0
    }

    var $losses {
      value = 0
    }

    var $falls {
      value = 0
    }

    var $tech_falls {
      value = 0
    }

    var $majors {
      value = 0
    }

    foreach ($matches) {
      each as $m {
        var $is_winner {
          value = $m.winner_canonical_wrestler_id == $input.canonical_wrestler_id
        }

        function.run normalize_victory_type {
          input = {raw: $m.victory_type}
        } as $vt

        conditional {
          if ($is_winner) {
            math.add $wins {
              value = 1
            }

            conditional {
              if ($vt == "fall") {
                math.add $falls {
                  value = 1
                }
              }
              elseif ($vt == "tech_fall") {
                math.add $tech_falls {
                  value = 1
                }
              }
              elseif ($vt == "major") {
                math.add $majors {
                  value = 1
                }
              }
            }
          }
          else {
            math.add $losses {
              value = 1
            }
          }
        }
      }
    }
  }

  response = {
    wins      : $wins
    losses    : $losses
    falls     : $falls
    tech_falls: $tech_falls
    majors    : $majors
  }
  guid = "J0sqS96Pk0mjPTpp-C2jt56uMX4"
}

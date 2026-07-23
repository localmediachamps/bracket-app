// Turns a {wrestler_id_text: count} map (built via bump_season_map, keyed by
// canonical_wrestler.id as text - a generic counter, not season-specific
// despite the function's name) into a sorted top-N leaderboard with each
// wrestler's display_name/team/weight_class resolved for display. Used by
// tasks/compute_season_stat_leaders.xs for the wins/pins/tech-fall boards.
function build_stat_leader_list {
  input {
    json counts_map
    int limit?=10
  }

  stack {
    var $ids {
      value = ($input.counts_map|keys)
    }

    var $entries {
      value = []
    }

    foreach ($ids) {
      each as $wid_text {
        array.push $entries {
          value = {wrestler_id: ($wid_text|to_int), count: $input.counts_map[$wid_text]}
        }
      }
    }

    var $sorted_desc {
      value = ($entries|sort:"count":"number")|reverse
    }

    var $top {
      value = $sorted_desc|slice:0:$input.limit
    }

    var $out {
      value = []
    }

    foreach ($top) {
      each as $e {
        db.get canonical_wrestler {
          field_name = "id"
          field_value = $e.wrestler_id
        } as $w

        var $team_name { value = null }
        var $display_name { value = null }
        var $weight_class { value = null }

        conditional {
          if ($w != null) {
            var.update $display_name { value = $w.display_name }
            var.update $weight_class { value = $w.current_weight_class }

            conditional {
              if ($w.current_team_id != null) {
                db.get canonical_team {
                  field_name = "id"
                  field_value = $w.current_team_id
                } as $t

                conditional {
                  if ($t != null) {
                    var.update $team_name { value = $t.name }
                  }
                }
              }
            }
          }
        }

        array.push $out {
          value = {
            wrestler_id : $e.wrestler_id
            display_name: $display_name
            team_name   : $team_name
            weight_class: $weight_class
            count       : $e.count
          }
        }
      }
    }
  }

  response = $out
  guid = "CdQlQT4X1exiuKBhGGeZ8MRxs9M"
}

// Processes ONE dual meet's worth of bout rows (already grouped by the
// caller) into a dual_meet + dual_meet_weight_slot record set. Extracted out
// of reconcile_historical_dual_meets.xs so it can be called once per GROUP
// (~2,000 calls total) via function.run rather than duplicating this logic
// inline at both flush points of a streaming loop - calling it once per
// BOUT ROW instead (~19k calls) would hit the same per-call overhead wall
// documented in compute_stat_leaders_for_season.xs, but once per group is a
// completely different, cheap order of magnitude.
//
// Victory-type classification is inlined (same cascade as
// normalize_victory_type.xs, kept manually in sync) for the same reason
// row-level function.run calls are avoided - this function's own per-row
// loop is still bounded to one group's ~10 rows, so it's cheap regardless,
// but keeping it inline avoids yet another nested function.run layer.
function process_historical_dual_meet_group {
  input {
    text event_id
    json rows
    json team_id_by_name
  }

  stack {
    var $first { value = $input.rows|get:0:null }

    var $away_name { value = null }

    conditional {
      if ($first.event_name != null && ($first.event_name|starts_with:"vs. ")) {
        var.update $away_name { value = ($first.event_name|substr:4:200)|trim }
      }
    }

    var $schools { value = {} }

    foreach ($input.rows) {
      each as $r2 {
        conditional {
          if ($r2.winner_school_raw != null && ($r2.winner_school_raw|strlen) > 0) {
            var.update $schools { value = $schools|set:$r2.winner_school_raw:true }
          }
        }

        conditional {
          if ($r2.loser_school_raw != null && ($r2.loser_school_raw|strlen) > 0) {
            var.update $schools { value = $schools|set:$r2.loser_school_raw:true }
          }
        }
      }
    }

    var $school_names { value = ($schools|keys) }
    var $school_count { value = ($school_names|count) }

    var $home_name { value = null }

    conditional {
      if ($school_count == 2 && $away_name != null && ($schools|has:$away_name)) {
        foreach ($school_names) {
          each as $sn {
            conditional {
              if ($sn != $away_name) {
                var.update $home_name { value = $sn }
              }
            }
          }
        }
      }
    }

    var $created { value = false }
    var $skipped { value = false }
    var $slot_write_count { value = 0 }

    conditional {
      if ($home_name == null || $away_name == null) {
        var.update $skipped { value = true }
      }
      else {
        var $home_score { value = 0 }
        var $away_score { value = 0 }
        var $slot_data { value = [] }

        foreach ($input.rows) {
          each as $r3 {
            var $vt { value = "" }

            conditional {
              if ($r3.victory_type != null) {
                var.update $vt { value = $r3.victory_type|to_lower|trim }
              }
            }

            var $has_medical { value = $vt|contains:"medical" }
            var $has_inj { value = $vt|contains:"inj" }
            var $is_default_w { value = $vt == "default" }
            var $has_disq { value = $vt|contains:"disq" }
            var $has_dq { value = $vt|contains:"dq" }
            var $has_forfeit { value = $vt|contains:"forfeit" }
            var $is_ff { value = $vt == "ff" }
            var $starts_for { value = $vt|starts_with:"for" }
            var $has_tech { value = $vt|contains:"tech" }
            var $has_fall { value = $vt|contains:"fall" }
            var $has_pin { value = $vt|contains:"pin" }
            var $has_maj { value = $vt|contains:"maj" }
            var $has_dec { value = $vt|contains:"dec" }
            var $has_sv { value = $vt|contains:"sudden victory" }
            var $has_tb { value = $vt|contains:"tie breaker" }
            var $has_tbn { value = $vt|contains:"tiebreaker" }

            var $is_injury_default { value = $has_inj || $is_default_w }
            var $is_disqualification { value = $has_disq || $has_dq }
            var $is_forfeit_a { value = $has_forfeit || $is_ff }
            var $is_forfeit { value = $is_forfeit_a || $starts_for }
            var $is_fall_type { value = $has_fall || $has_pin }
            var $is_decision_a { value = $has_dec || $has_sv }
            var $is_decision_b { value = $has_tb || $has_tbn }
            var $is_decision { value = $is_decision_a || $is_decision_b }

            var $canon_vt { value = null }

            conditional {
              if ($has_medical) {
                var.update $canon_vt { value = "medical_forfeit" }
              }
              elseif ($is_injury_default) {
                var.update $canon_vt { value = "injury_default" }
              }
              elseif ($is_disqualification) {
                var.update $canon_vt { value = "disqualification" }
              }
              elseif ($is_forfeit) {
                var.update $canon_vt { value = "forfeit" }
              }
              elseif ($has_tech) {
                var.update $canon_vt { value = "tech_fall" }
              }
              elseif ($is_fall_type) {
                var.update $canon_vt { value = "fall" }
              }
              elseif ($has_maj) {
                var.update $canon_vt { value = "major" }
              }
              elseif ($is_decision) {
                var.update $canon_vt { value = "decision" }
              }
            }

            conditional {
              if ($canon_vt != null) {
                var $points { value = 6 }

                conditional {
                  if ($canon_vt == "tech_fall") {
                    var.update $points { value = 5 }
                  }
                  elseif ($canon_vt == "major") {
                    var.update $points { value = 4 }
                  }
                  elseif ($canon_vt == "decision") {
                    var.update $points { value = 3 }
                  }
                }

                var $winner_is_home { value = $r3.winner_school_raw == $home_name }

                conditional {
                  if ($winner_is_home) {
                    math.add $home_score { value = $points }
                  }
                  else {
                    math.add $away_score { value = $points }
                  }
                }

                var $home_wrestler { value = $r3.loser_name_raw }
                var $away_wrestler { value = $r3.winner_name_raw }
                var $winner_side { value = "away" }

                conditional {
                  if ($winner_is_home) {
                    var.update $home_wrestler { value = $r3.winner_name_raw }
                    var.update $away_wrestler { value = $r3.loser_name_raw }
                    var.update $winner_side { value = "home" }
                  }
                }

                array.push $slot_data {
                  value = {
                    weight             : ($r3.weight_class|to_int)
                    home_wrestler_name : $home_wrestler
                    away_wrestler_name : $away_wrestler
                    actual_winner_side : $winner_side
                    actual_victory_type: $canon_vt
                    occurred           : true
                  }
                }
              }
            }
          }
        }

        var $sorted_slots { value = $slot_data|sort:"weight":"number" }

        var $year_text { value = ($first.date_start_raw|substr:0:4) }
        var $year_num { value = $year_text|to_int }

        var $display_name { value = $away_name ~ " at " ~ $home_name }

        var $slug_base { value = $display_name|to_lower|unaccent|trim }
        var.update $slug_base { value = "/[^a-z0-9]+/"|regex_replace:"-":$slug_base }
        var.update $slug_base { value = $slug_base|trim:"-" }
        var $slug { value = $slug_base ~ "-" ~ $input.event_id }

        var $home_team_id { value = $input.team_id_by_name|get:$home_name:null }
        var $away_team_id { value = $input.team_id_by_name|get:$away_name:null }

        db.add_or_edit dual_meet {
          field_name = "source_match_key"
          field_value = $input.event_id
          data = {
            name                    : $display_name
            year                    : $year_num
            slug                    : $slug
            home_canonical_team_id  : $home_team_id
            away_canonical_team_id  : $away_team_id
            home_team_name          : $home_name
            away_team_name          : $away_name
            occurred_at             : $first.occurred_at
            status                  : "completed"
            visibility              : "public"
            created_by              : 1
            entry_count             : 0
            source_match_key        : $input.event_id
            is_historical           : true
            home_score              : $home_score
            away_score              : $away_score
          }
        } as $dm

        db.bulk.delete dual_meet_weight_slot {
          where = $db.dual_meet_weight_slot.dual_meet_id == $dm.id
        } as $deleted_slots

        foreach ($sorted_slots) {
          each as $sd {
            db.add dual_meet_weight_slot {
              data = {
                dual_meet_id       : $dm.id
                weight             : $sd.weight
                display_order      : $sd.weight
                home_wrestler_name : $sd.home_wrestler_name
                away_wrestler_name : $sd.away_wrestler_name
                actual_winner_side : $sd.actual_winner_side
                actual_victory_type: $sd.actual_victory_type
                occurred           : true
              }
            } as $new_slot

            math.add $slot_write_count { value = 1 }
          }
        }

        var.update $created { value = true }
      }
    }
  }

  response = {
    created      : $created
    skipped      : $skipped
    slots_written: $slot_write_count
  }
  guid = "lVTCggMslAn4bLAVwC9j0NLqDA8"
}

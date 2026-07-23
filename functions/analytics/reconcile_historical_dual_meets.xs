// Groups every event_type=="dual" row in wrestler_match_history (one row per
// individual bout) by event_id_external into real dual_meet +
// dual_meet_weight_slot records - the reconciliation that turns "vs. Bucknell"
// (one team's own schedule text, no opponent-of-the-opponent framing, no
// score) into a real two-team record with a final NCAA dual score, browsable
// the same way tournament results are. Idempotent via source_match_key =
// event_id_external (db.add_or_edit + wipe-and-rebuild the weight slots each
// run), so re-running after a historical-data backfill correction is safe.
//
// Home/away is NOT true home-venue - that isn't recoverable from this raw
// data. It's derived from event_name's "vs. {opponent}" convention: whichever
// school is NOT the named opponent is treated as "home" (the schedule
// owner), matching the same home/away framing admin/dual-meets/from-history
// already uses for manually-created historical duals.
//
// IMPORTANT: victory-type classification is inlined here (same full cascade
// as normalize_victory_type.xs, kept manually in sync - see that file) rather
// than called via function.run, and slug generation is inlined from
// slugify.xs rather than called. Both are called once per BOUT ROW (~19k
// rows) if done via function.run, which - per the perf lesson in
// compute_stat_leaders_for_season.xs - is too slow at this row count.
// (db.bulk.add turned out to reject a variable `data` array at parse time -
// only literal array syntax - so weight slots are written one db.add per
// slot instead; ~10 slots/meet keeps this bounded.)
function reconcile_historical_dual_meets {
  input {
  }

  stack {
    db.query wrestler_match_history {
      where = $db.wrestler_match_history.event_type == "dual"
      sort = {wrestler_match_history.id: "asc"}
      return = {
        type  : "list"
        paging: {page: 1, per_page: 30000, totals: true}
      }
    } as $page_result

    var $all_rows { value = $page_result.items }

    // Small, cheap table - fetch all once for in-memory name->id lookup
    // rather than a db.get per group (same pattern as results/wrestlers/{id}).
    db.query canonical_team {
      return = {type: "list"}
    } as $teams

    var $team_id_by_name { value = {} }

    foreach ($teams) {
      each as $t {
        var.update $team_id_by_name { value = $team_id_by_name|set:$t.name:$t.id }
      }
    }

    // Group bout rows by event_id_external
    var $groups { value = {} }

    foreach ($all_rows) {
      each as $r {
        var $ek { value = $r.event_id_external }

        conditional {
          if ($ek != null && ($ek|strlen) > 0) {
            var $existing { value = [] }

            conditional {
              if ($groups|has:$ek) {
                var.update $existing { value = $groups[$ek] }
              }
            }

            array.push $existing { value = $r }
            var.update $groups { value = $groups|set:$ek:$existing }
          }
        }
      }
    }

    var $event_ids { value = ($groups|keys) }

    var $created_count { value = 0 }
    var $skipped_count { value = 0 }
    var $slots_written { value = 0 }

    foreach ($event_ids) {
      each as $ek {
        var $rows { value = $groups[$ek] }
        var $first { value = $rows|get:0:null }

        var $away_name { value = null }

        conditional {
          if ($first.event_name != null && ($first.event_name|starts_with:"vs. ")) {
            var.update $away_name { value = ($first.event_name|substr:4:200)|trim }
          }
        }

        // Distinct schools mentioned anywhere in this group's bouts
        var $schools { value = {} }

        foreach ($rows) {
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

        conditional {
          if ($home_name == null || $away_name == null) {
            math.add $skipped_count { value = 1 }
          }
          else {
            var $home_score { value = 0 }
            var $away_score { value = 0 }
            var $slot_data { value = [] }

            foreach ($rows) {
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
            var $slug { value = $slug_base ~ "-" ~ $ek }

            var $home_team_id { value = $team_id_by_name|get:$home_name:null }
            var $away_team_id { value = $team_id_by_name|get:$away_name:null }

            db.add_or_edit dual_meet {
              field_name = "source_match_key"
              field_value = $ek
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
                source_match_key        : $ek
                is_historical           : true
                home_score              : $home_score
                away_score              : $away_score
              }
            } as $dm

            db.bulk.delete dual_meet_weight_slot {
              where = $db.dual_meet_weight_slot.dual_meet_id == $dm.id
            } as $deleted_slots

            var $slot_write_count { value = 0 }

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

            math.add $created_count { value = 1 }
            math.add $slots_written { value = $slot_write_count }
          }
        }
      }
    }
  }

  response = {
    dual_rows_scanned: ($all_rows|count)
    events_found     : ($event_ids|count)
    reconciled       : $created_count
    skipped          : $skipped_count
    slots_written    : $slots_written
  }
  guid = "1jXMmcYGL-cSBOHGBg6H1-bK44c"
}

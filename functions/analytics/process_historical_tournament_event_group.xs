// Processes ONE tournament event's worth of match rows (already grouped by
// the caller, same streaming pattern as process_historical_dual_meet_group.xs)
// into a historical_tournament_event + one historical_tournament_event_team
// row per participating school. Wrestler/starter counts are approximate
// (distinct wrestler_name_raw per school, not canonical-identity-deduped),
// good enough for "did this team send a real lineup or basically nobody."
function process_historical_tournament_event_group {
  input {
    text event_id
    json rows
    json team_id_by_name

    // wrestler_id (text) -> true, for every wrestler tagged is_starter for
    // the relevant season - built ONCE by the caller (reconcile_historical_
    // tournament_events.xs), not re-queried per group/wrestler.
    json starter_wrestler_ids

    text season_label
  }

  stack {
    var $first { value = $input.rows|get:0:null }

    var $min_occurred { value = $first.occurred_at }
    var $max_occurred { value = $first.occurred_at }

    // team_name_raw -> {wrestler_name_raw (text) -> canonical_wrestler_id (nullable)}
    var $team_wrestlers { value = {} }

    foreach ($input.rows) {
      each as $r {
        conditional {
          if ($r.occurred_at != null && $r.occurred_at < $min_occurred) {
            var.update $min_occurred { value = $r.occurred_at }
          }
        }

        conditional {
          if ($r.occurred_at != null && $r.occurred_at > $max_occurred) {
            var.update $max_occurred { value = $r.occurred_at }
          }
        }

        conditional {
          if ($r.winner_school_raw != null && ($r.winner_school_raw|strlen) > 0 && $r.winner_name_raw != null) {
            var $w_existing { value = $team_wrestlers|get:$r.winner_school_raw:{} }
            var.update $w_existing { value = $w_existing|set:$r.winner_name_raw:$r.winner_canonical_wrestler_id }
            var.update $team_wrestlers { value = $team_wrestlers|set:$r.winner_school_raw:$w_existing }
          }
        }

        conditional {
          if ($r.loser_school_raw != null && ($r.loser_school_raw|strlen) > 0 && $r.loser_name_raw != null) {
            var $l_existing { value = $team_wrestlers|get:$r.loser_school_raw:{} }
            var.update $l_existing { value = $l_existing|set:$r.loser_name_raw:$r.loser_canonical_wrestler_id }
            var.update $team_wrestlers { value = $team_wrestlers|set:$r.loser_school_raw:$l_existing }
          }
        }
      }
    }

    var $school_names { value = ($team_wrestlers|keys) }

    var $display_name { value = ($first.event_series_name != null ? $first.event_series_name : $first.event_name) }

    var $slug_base { value = $display_name|to_lower|unaccent|trim }
    var.update $slug_base { value = "/[^a-z0-9]+/"|regex_replace:"-":$slug_base }
    var.update $slug_base { value = $slug_base|trim:"-" }

    db.add_or_edit historical_tournament_event {
      field_name = "event_id_external"
      field_value = $input.event_id
      data = {
        name             : $display_name
        series_name      : $first.event_series_name
        event_id_external: $input.event_id
        starts_at        : $min_occurred
        ends_at          : $max_occurred
        match_count      : ($input.rows|count)
        team_count       : ($school_names|count)
        season_label     : $input.season_label
      }
    } as $event

    db.bulk.delete historical_tournament_event_team {
      where = $db.historical_tournament_event_team.event_id == $event.id
    } as $deleted_teams

    var $teams_written { value = 0 }

    foreach ($school_names) {
      each as $sn {
        var $wrestler_map { value = $team_wrestlers|get:$sn:{} }
        var $wrestler_names { value = ($wrestler_map|keys) }
        var $w_count { value = ($wrestler_names|count) }

        var $starter_count { value = 0 }

        foreach ($wrestler_names) {
          each as $wn {
            var $wid { value = $wrestler_map|get:$wn:null }

            conditional {
              if ($wid != null) {
                var $wid_key { value = ($wid|to_text) }

                conditional {
                  if ($input.starter_wrestler_ids|has:$wid_key) {
                    math.add $starter_count { value = 1 }
                  }
                }
              }
            }
          }
        }

        var $resolved_team_id { value = $input.team_id_by_name|get:$sn:null }

        db.add historical_tournament_event_team {
          data = {
            event_id         : $event.id
            canonical_team_id: $resolved_team_id
            team_name_raw    : $sn
            wrestler_count   : $w_count
            starter_count    : $starter_count
          }
        } as $new_team_row

        math.add $teams_written { value = 1 }
      }
    }
  }

  response = {
    event_id     : $event.id
    teams_written: $teams_written
  }
  guid = "Zq2oXp5YlSu7NeTrAv8JdLf4HiYg6"
}

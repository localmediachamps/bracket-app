// Week-by-week breakdown of a season's real schedule, built from the
// already-reconciled dual_meet + historical_tournament_event(_team) data -
// for evaluating whether a given week is dominated by dual meets (plain
// head-to-head makes sense) or has real tournament activity where only a
// fraction of teams' actual starters attend (a real design question for
// marquee-week scoring, see 2026-07-24 discussion).
//
// Tournament events sharing the same NAME within the SAME week are merged
// into one canonical row - the source data records something like "Rutgers
// Quad" as several separate 2-team dual rows (one per opponent), which
// would otherwise look like duplicate events. Merging unions each team's
// actual wrestler/starter NAME lists (not just summed counts) across the
// merged sub-events, so a wrestler who wrestled multiple matches at the
// same quad is counted once, not once per match - summing counts would
// have double/triple-counted them. Same-named events are only merged
// WITHIN one week, not across the whole season, since some real events
// recur under a generic name (e.g. "VMI Tri Meet") at genuinely different
// points in the year.
query "admin/schedule/week-analysis" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    int season_id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.query season_week {
      where = $db.season_week.season_id == $input.season_id
      sort = {season_week.week_number: "asc"}
      return = {type: "list"}
    } as $weeks

    db.get season {
      field_name = "id"
      field_value = $input.season_id
    } as $season

    function.run season_label_from_year {
      input = {year: $season.year}
    } as $season_label

    db.query canonical_wrestler_team {
      where = $db.canonical_wrestler_team.season_label == $season_label && $db.canonical_wrestler_team.is_starter == true
      return = {type: "list", paging: {page: 1, per_page: 50000}}
    } as $all_starters

    var $total_starters_national { value = ($all_starters.items|count) }

    db.query dual_meet {
      where = $db.dual_meet.is_historical == true
      return = {type: "list", paging: {page: 1, per_page: 50000}}
    } as $all_duals

    db.query historical_tournament_event {
      where = $db.historical_tournament_event.season_label == $season_label
      return = {type: "list"}
    } as $all_events

    db.query historical_tournament_event_team {
      return = {type: "list", paging: {page: 1, per_page: 50000}}
    } as $all_event_teams

    var $week_summaries { value = [] }

    foreach ($weeks) {
      each as $w {
        // Real dual meets this week - actual matchups, not just a count.
        var $week_duals { value = [] }

        foreach ($all_duals.items) {
          each as $dm {
            conditional {
              if ($dm.occurred_at != null && $dm.occurred_at >= $w.starts_at && $dm.occurred_at <= $w.ends_at) {
                array.push $week_duals {
                  value = {
                    dual_meet_id : $dm.id
                    home_team    : $dm.home_team_name
                    away_team    : $dm.away_team_name
                    home_score   : $dm.home_score
                    away_score   : $dm.away_score
                    occurred_at  : $dm.occurred_at
                  }
                }
              }
            }
          }
        }

        // Tournament events overlapping this week. Kept as a plain,
        // push-built array (never a value retrieved out of a map with
        // |get:) - a map value retrieved via |get: throws a fatal engine
        // error ("Please use a numerically indexed array") the moment it's
        // foreach'd, even after copying it with array.merge into a fresh
        // array first. Every foreach target below is either a real db.query
        // result or a plain array built via array.push, never a |get: value.
        var $week_events_raw { value = [] }

        foreach ($all_events) {
          each as $ev {
            var $overlaps { value = ($ev.starts_at <= $w.ends_at && $ev.ends_at >= $w.starts_at) }
            conditional {
              if ($overlaps) {
                array.push $week_events_raw { value = $ev }
              }
            }
          }
        }

        // Ids stored/compared as text - matching this codebase's established
        // fix for XanoScript's unreliable bare-int equality/membership checks
        // (see CLAUDE.md "int == int" note).
        var $week_event_ids { value = [] }
        foreach ($week_events_raw) {
          each as $ev {
            array.push $week_event_ids { value = ($ev.id|to_text) }
          }
        }

        // Event-team rows relevant to this week only, filtered once so the
        // per-group pass below scans a small list instead of the full
        // season's event_team table each time.
        //
        // NOT `$array|has:value` - a newly confirmed engine bug: |has:
        // returns false even for an exact literal match (confirmed via
        // isolated test: (["4","5"]|has:"4") evaluates to false). Manual
        // foreach-based membership comparison works correctly and is used
        // everywhere below instead.
        var $week_event_teams { value = [] }
        foreach ($all_event_teams.items) {
          each as $et {
            var $et_eid_txt { value = ($et.event_id|to_text) }
            var $et_in_week { value = false }
            foreach ($week_event_ids) {
              each as $wid {
                conditional {
                  if ($wid == $et_eid_txt) {
                    var.update $et_in_week { value = true }
                  }
                }
              }
            }
            conditional {
              if ($et_in_week == true) {
                array.push $week_event_teams { value = $et }
              }
            }
          }
        }

        // Unique event names this week - same-named sub-events (e.g. each
        // opponent of a quad meet recorded as its own row) get merged into
        // one canonical group below.
        var $group_names { value = [] }
        foreach ($week_events_raw) {
          each as $ev {
            var $name_seen { value = false }
            foreach ($group_names) {
              each as $gn {
                conditional {
                  if ($gn == $ev.name) {
                    var.update $name_seen { value = true }
                  }
                }
              }
            }
            conditional {
              if ($name_seen == true) {
                // already tracked
              }
              else {
                array.push $group_names { value = $ev.name }
              }
            }
          }
        }

        var $week_events { value = [] }
        var $dual_tournament_count { value = 0 }
        var $individual_tournament_count { value = 0 }
        var $week_starter_names { value = {} }

        foreach ($group_names) {
          each as $gname {
            var $group_ids { value = [] }
            var $gstart { value = null }
            var $gend { value = null }
            var $gmatch_count { value = 0 }

            foreach ($week_events_raw) {
              each as $ev {
                conditional {
                  if ($ev.name == $gname) {
                    array.push $group_ids { value = ($ev.id|to_text) }
                    math.add $gmatch_count { value = $ev.match_count }
                    conditional {
                      if ($gstart == null || $ev.starts_at < $gstart) {
                        var.update $gstart { value = $ev.starts_at }
                      }
                    }
                    conditional {
                      if ($gend == null || $ev.ends_at > $gend) {
                        var.update $gend { value = $ev.ends_at }
                      }
                    }
                  }
                }
              }
            }

            var $team_names_seen { value = {} }
            var $wrestler_names_seen { value = {} }
            var $starter_names_seen { value = {} }

            foreach ($week_event_teams) {
              each as $et {
                var $et_eid_txt2 { value = ($et.event_id|to_text) }
                var $et_in_group { value = false }
                foreach ($group_ids) {
                  each as $gid {
                    conditional {
                      if ($gid == $et_eid_txt2) {
                        var.update $et_in_group { value = true }
                      }
                    }
                  }
                }
                conditional {
                  if ($et_in_group == true) {
                    var.update $team_names_seen { value = $team_names_seen|set:$et.team_name_raw:true }

                    foreach ($et.wrestler_names) {
                      each as $wn {
                        var.update $wrestler_names_seen { value = $wrestler_names_seen|set:$wn:true }
                      }
                    }

                    foreach ($et.starter_wrestler_names) {
                      each as $sn {
                        var.update $starter_names_seen { value = $starter_names_seen|set:$sn:true }
                        var.update $week_starter_names { value = $week_starter_names|set:$sn:true }
                      }
                    }
                  }
                }
              }
            }

            var $group_team_count { value = (($team_names_seen|keys)|count) }
            var $group_wrestler_count { value = (($wrestler_names_seen|keys)|count) }
            var $group_starter_count { value = (($starter_names_seen|keys)|count) }

            conditional {
              if ($group_team_count <= 2) {
                math.add $dual_tournament_count { value = 1 }
              }
              else {
                math.add $individual_tournament_count { value = 1 }
              }
            }

            array.push $week_events {
              value = {
                name               : $gname
                starts_at          : $gstart
                ends_at            : $gend
                team_count         : $group_team_count
                match_count        : $gmatch_count
                wrestlers_competing: $group_wrestler_count
                starters_competing : $group_starter_count
                is_dual_tournament : ($group_team_count <= 2)
              }
            }
          }
        }

        var $week_starter_participation { value = (($week_starter_names|keys)|count) }
        var $starter_pct { value = 0 }

        conditional {
          if ($total_starters_national > 0) {
            var.update $starter_pct { value = (($week_starter_participation / $total_starters_national) * 100) }
          }
        }

        array.push $week_summaries {
          value = {
            week_number             : $w.week_number
            week_type               : $w.week_type
            starts_at               : $w.starts_at
            ends_at                 : $w.ends_at
            dual_meets              : $week_duals
            dual_meet_count         : ($week_duals|count)
            dual_tournament_count   : $dual_tournament_count
            individual_tournament_count: $individual_tournament_count
            tournament_events       : $week_events
            starters_participating  : $week_starter_participation
            starter_participation_pct: $starter_pct
          }
        }
      }
    }
  }

  response = {
    season_label           : $season_label
    total_starters_national: $total_starters_national
    weeks                  : $week_summaries
  }
  guid = "Cs5rZt8BoVx1QhWuDy2MgOi7LlBj9"
}

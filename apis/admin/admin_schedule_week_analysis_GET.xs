// Week-by-week breakdown of a season's real schedule, built from the
// already-reconciled dual_meet + historical_tournament_event(_team) data -
// for evaluating whether a given week is dominated by dual meets (plain
// head-to-head makes sense) or has real tournament activity where only a
// fraction of teams' actual starters attend (a real design question for
// marquee-week scoring, see 2026-07-24 discussion). A tournament event
// counts as "dual_tournament" if only 2 teams participated (structurally a
// dual, even though tagged event_type=tournament in the source data) vs
// "individual_tournament" for anything with more participants - a
// heuristic, not a guarantee, since raw event_type doesn't capture this
// distinction directly.
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

    // Fixed denominator - total real starters tagged for this season,
    // league-wide across every D1 team, not scoped to any one fantasy league.
    db.query canonical_wrestler_team {
      where = $db.canonical_wrestler_team.season_label == $season_label && $db.canonical_wrestler_team.is_starter == true
      return = {type: "list", paging: {page: 1, per_page: 50000}}
    } as $all_starters

    var $total_starters_national { value = ($all_starters.items|count) }

    // Fetch once, filter per week in-memory rather than one query per week.
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

    var $starters_by_event { value = {} }

    foreach ($all_event_teams.items) {
      each as $et {
        var $ekey { value = ($et.event_id|to_text) }

        // NOT |get:key:0 - a confirmed XanoScript engine bug returns null
        // instead of the default specifically when that default is 0 (see
        // CLAUDE.md) - always null-check explicitly instead.
        var $prev_raw { value = $starters_by_event|get:$ekey:null }
        var $prev { value = ($prev_raw != null ? $prev_raw : 0) }

        var $et_starters { value = ($et.starter_count != null ? $et.starter_count : 0) }

        var.update $starters_by_event { value = $starters_by_event|set:$ekey:($prev + $et_starters) }
      }
    }

    var $week_summaries { value = [] }

    foreach ($weeks) {
      each as $w {
        var $dual_count { value = 0 }

        foreach ($all_duals.items) {
          each as $dm {
            conditional {
              if ($dm.occurred_at != null && $dm.occurred_at >= $w.starts_at && $dm.occurred_at <= $w.ends_at) {
                math.add $dual_count { value = 1 }
              }
            }
          }
        }

        var $week_events { value = [] }
        var $dual_tournament_count { value = 0 }
        var $individual_tournament_count { value = 0 }
        var $week_starter_participation { value = 0 }

        foreach ($all_events) {
          each as $ev {
            var $overlaps { value = ($ev.starts_at <= $w.ends_at && $ev.ends_at >= $w.starts_at) }

            conditional {
              if ($overlaps) {
                var $ev_key { value = ($ev.id|to_text) }
                var $ev_starters_raw { value = $starters_by_event|get:$ev_key:null }
                var $ev_starters { value = ($ev_starters_raw != null ? $ev_starters_raw : 0) }

                math.add $week_starter_participation { value = $ev_starters }

                conditional {
                  if ($ev.team_count != null && $ev.team_count <= 2) {
                    math.add $dual_tournament_count { value = 1 }
                  }
                  else {
                    math.add $individual_tournament_count { value = 1 }
                  }
                }

                array.push $week_events {
                  value = {
                    name        : $ev.name
                    starts_at   : $ev.starts_at
                    ends_at     : $ev.ends_at
                    team_count  : $ev.team_count
                    match_count : $ev.match_count
                    starters_participating: $ev_starters
                  }
                }
              }
            }
          }
        }

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
            dual_meet_count         : $dual_count
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

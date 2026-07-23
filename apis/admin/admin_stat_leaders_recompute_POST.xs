// Force-refreshes season_stat_leaders on demand (normally handled by the
// daily tasks/compute_season_stat_leaders task). Useful right after a
// historical-data backfill/correction lands and you don't want to wait for
// the schedule. Optional season_label recomputes just that season;
// omitted recomputes all 4 known seasons (same season_bounds as
// results/wrestlers/{id}).
query "admin/stat-leaders/recompute" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    text? season_label? filters=trim
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $season_bounds {
      value = [
        {label: "2022-23", start: 1659312000000, end: 1690847999000}
        {label: "2023-24", start: 1690848000000, end: 1722470399000}
        {label: "2024-25", start: 1722470400000, end: 1754006399000}
        {label: "2025-26", start: 1754006400000, end: 1785628799000}
      ]
    }

    var $results { value = [] }

    foreach ($season_bounds) {
      each as $sb {
        conditional {
          if ($input.season_label == null || $input.season_label == $sb.label) {
            function.run compute_stat_leaders_for_season {
              input = {season_label: $sb.label, season_start: $sb.start, season_end: $sb.end}
            } as $season_result

            array.push $results {
              value = $season_result
            }
          }
        }
      }
    }
  }

  response = {
    recomputed: $results
  }
  guid = "emL4vjDoDjssLNUa8a11--AKXgc"
}

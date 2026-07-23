// Refreshes every season's row in season_stat_leaders by delegating to
// functions/analytics/compute_stat_leaders_for_season.xs. Runs daily, mainly
// to pick up ongoing historical-data backfill corrections since the 3 older
// seasons are otherwise final. Same fixed academic-year season_bounds as
// results/wrestlers/{id}. To force a refresh on demand (or test this path)
// use admin/stat-leaders/recompute instead of waiting for the schedule.
task compute_season_stat_leaders {
  stack {
    var $season_bounds {
      value = [
        {label: "2022-23", start: 1659312000000, end: 1690847999000}
        {label: "2023-24", start: 1690848000000, end: 1722470399000}
        {label: "2024-25", start: 1722470400000, end: 1754006399000}
        {label: "2025-26", start: 1754006400000, end: 1785628799000}
      ]
    }

    foreach ($season_bounds) {
      each as $sb {
        function.run compute_stat_leaders_for_season {
          input = {season_label: $sb.label, season_start: $sb.start, season_end: $sb.end}
        } as $season_result
      }
    }
  }

  schedule = [{starts_on: 2026-07-23 06:00:00+0000, freq: 86400}]
  guid = "GXsagmnUkXWm5dMGUgCpAbroN6M"
}

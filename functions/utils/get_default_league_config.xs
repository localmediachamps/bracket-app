// Returns the default season-league fantasy scoring configuration (fantasy
// league plan, Phase 6 + the 2026-07-22 conference/nationals redesign - see
// memory: conference_nationals_scoring_redesign). league.scoring_config
// overlays this key-by-key - nothing here is hardcoded into the scoring
// cron itself.
// victory_points: base points per real match, before averaging, keyed by the
// full victory-type enum. medal_bonus: flat bonus on top of the average for
// wrestlers who placed at a tournament that week, keyed by placement (parsed
// from round_label the same way Results.jsx's placementInfo() does).
// opponent_multipliers: same tier shape/starting values as the tournament
// bracket/pickem scorer's own get_default_scoring_config.xs, for consistency
// app-wide - a no-op (1x) until wrestler_composite_ranking has real data.
// head_to_head_result_points: flat points a head_to_head week's win/tie/loss
// result adds to the season-long standings ledger (on top of, not instead
// of, the per-match averaging that decides the winner).
// placement_points_defaults: fallback rank->points tables, keyed by week_type
// (marquee_tournament/conference/nationals), used only when a specific
// season_week's own placement_points_config is null. Every week type feeds
// the SAME season_week_tournament_result ledger - conference/nationals
// counting for more than a regular week is entirely a function of these
// tables' own values (e.g. nationals' 1st-place value being much higher than
// marquee's), not a separate weight_multiplier field.
function get_default_league_config {
  input {
  }

  stack {
    // Base points per real match, by victory_type
    var $victory_points {
      value = {}
        |set:"decision":3
        |set:"major":4
        |set:"tech_fall":5
        |set:"fall":6
        |set:"medical_forfeit":3
        |set:"injury_default":3
        |set:"forfeit":6
        |set:"disqualification":6
        |set:"default":0
    }

    // Flat bonus on top of the week's average, by tournament placement
    var $medal_bonus {
      value = {}
        |set:"1":6
        |set:"2":4
        |set:"3":3
        |set:"4":2
        |set:"5":1
        |set:"6":1
        |set:"7":0.5
        |set:"8":0.5
        |set:"default":0
    }

    // Opponent-quality multiplier tiers, applied per match before averaging -
    // same shape/values as the bracket/pickem scorer's opponent_multipliers,
    // kept consistent app-wide. No effect until wrestler_composite_ranking
    // has real data for the beaten opponent.
    var $opponent_multipliers {
      value = {
        contender   : {min_rank: 1, max_rank: 4, multiplier: 1.5}
        all_american: {min_rank: 5, max_rank: 8, multiplier: 1.3}
        blood_round : {min_rank: 9, max_rank: 12, multiplier: 1.15}
      }
    }

    // Flat points a head-to-head result adds to the season standings ledger,
    // on top of the per-match-average score that decided the matchup.
    var $head_to_head_result_points {
      value = {}
        |set:"win":2
        |set:"tie":1
        |set:"loss":0
    }

    // Fallback placement->points tables per week_type, used only when a
    // season_week's own placement_points_config is null. Values are examples
    // from Garrett's own explanation of the relative weighting he wants
    // (marquee 1st=6, conference 1st=12, nationals 1st=20) - fully
    // commissioner-overridable per week, not fixed. Each table is built as
    // its own var first (same pattern as victory_points/medal_bonus above)
    // rather than as a nested filter chain inside an object literal.
    var $placement_marquee {
      value = {}
        |set:"1":6
        |set:"2":5
        |set:"3":4
        |set:"4":3
        |set:"5":2
        |set:"6":1
        |set:"7":1
        |set:"8":0.5
        |set:"default":0
    }

    var $placement_conference {
      value = {}
        |set:"1":12
        |set:"2":10
        |set:"3":8
        |set:"4":6
        |set:"5":5
        |set:"6":4
        |set:"7":3
        |set:"8":2
        |set:"default":0
    }

    var $placement_nationals {
      value = {}
        |set:"1":20
        |set:"2":16
        |set:"3":13
        |set:"4":11
        |set:"5":9
        |set:"6":7
        |set:"7":5
        |set:"8":4
        |set:"default":0
    }

    var $placement_points_defaults {
      value = {
        marquee_tournament: $placement_marquee
        conference        : $placement_conference
        nationals         : $placement_nationals
      }
    }

    var $config {
      value = {
        victory_points            : $victory_points
        medal_bonus               : $medal_bonus
        opponent_multipliers      : $opponent_multipliers
        head_to_head_result_points: $head_to_head_result_points
        placement_points_defaults : $placement_points_defaults
      }
    }
  }

  response = $config
  guid = "rGrKg3umvFtqrnNNA8pMNvVytVk"
}

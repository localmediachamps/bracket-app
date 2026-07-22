// Returns the default season-league fantasy scoring configuration (fantasy
// league plan, Phase 6). league.scoring_config overlays this key-by-key -
// nothing here is hardcoded into the scoring cron itself.
// victory_points: base points per real match, before averaging, keyed by the
// full victory-type enum. medal_bonus: flat bonus on top of the average for
// wrestlers who placed at a tournament that week, keyed by placement (parsed
// from round_label the same way Results.jsx's placementInfo() does).
// opponent_multipliers: same tier shape/starting values as the tournament
// bracket/pickem scorer's own get_default_scoring_config.xs, for consistency
// app-wide - a no-op (1x) until wrestler_composite_ranking has real data.
// postseason_weight: conference/nationals week weighting, with a cap on how
// much a single postseason week can swing the final standings.
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

    // conference/nationals week weighting - default_multiplier applies when
    // a league hasn't overridden it; max_multiplier caps how high a
    // commissioner-set override can go, so one postseason week can't swing
    // the whole season arbitrarily far.
    var $postseason_weight {
      value = {
        default_multiplier: 2
        max_multiplier    : 3
      }
    }

    var $config {
      value = {
        victory_points      : $victory_points
        medal_bonus         : $medal_bonus
        opponent_multipliers: $opponent_multipliers
        postseason_weight   : $postseason_weight
      }
    }
  }

  response = $config
  guid = "rGrKg3umvFtqrnNNA8pMNvVytVk"
}

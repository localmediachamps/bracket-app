// Returns the default scoring configuration for a tournament (ARCHITECTURE.md section 5).
// championship/consolation map round_number -> points.
// Lookup order for a match: pigtail -> pigtail; placement section -> placement[round_code];
// else section[round_number], falling back to the nearest defined lower round_number, else 1.
// Default versioned scoring config: per-round bracket points, dual-meet-style
// victory-type points, opponent-quality multiplier tiers, and tiebreaker order
function get_default_scoring_config {
  input {
  }

  stack {
    // Championship round_number -> points (rounds 1-6), doubling each round
    var $championship_points {
      value = {}
        |set:"1":1
        |set:"2":2
        |set:"3":4
        |set:"4":8
        |set:"5":16
        |set:"6":32
    }

    // Consolation round_number -> points: exactly half of the championship
    // round at the same key (keys 7-8 extend the same doubling pattern for
    // larger brackets that need extra early consolation/wrestleback rounds)
    var $consolation_points {
      value = {}
        |set:"1":0.5
        |set:"2":1
        |set:"3":2
        |set:"4":4
        |set:"5":8
        |set:"6":16
        |set:"7":32
        |set:"8":64
    }

    // Placement round_code -> points - flat bonuses, unaffected by the
    // opponent-quality multiplier below
    var $placement_points {
      value = {}
        |set:"place_3":4
        |set:"place_5":2
        |set:"place_7":2
    }

    // Flat points added on top of a correct pick's round points, by
    // victory_type - dual-meet team-scoring convention (decision=3,
    // major=4, tech_fall=5, fall=6). medical_forfeit/injury_default are
    // deliberately 3 instead of the usual dual-meet 6 (not a dominant win);
    // forfeit/disqualification keep the usual 6.
    var $victory_bonus_points {
      value = {}
        |set:"decision":3
        |set:"major":4
        |set:"tech_fall":5
        |set:"fall":6
        |set:"medical_forfeit":3
        |set:"injury_default":3
        |set:"forfeit":6
        |set:"disqualification":6
    }

    // Opponent-quality multiplier tiers, applied to a correct pick's round
    // points only (victory-type points and placement bonuses are untouched)
    // when the beaten opponent's composite national rank (not bracket seed)
    // falls in the tier's range. No effect until wrestler_composite_ranking
    // has real data - see that table's header comment.
    var $opponent_multipliers {
      value = {
        contender   : {min_rank: 1, max_rank: 4, multiplier: 1.5}
        all_american: {min_rank: 5, max_rank: 8, multiplier: 1.3}
        blood_round : {min_rank: 9, max_rank: 12, multiplier: 1.15}
      }
    }

    // Per-match points by bracket section
    var $bracket_config {
      value = {
        pigtail             : 1
        championship        : $championship_points
        consolation         : $consolation_points
        placement           : $placement_points
        champion_bonus      : 0
        victory_bonus_points: $victory_bonus_points
        opponent_multipliers: $opponent_multipliers
      }
    }

    // Versioned scoring config with tiebreaker order
    var $config {
      value = {
        version    : 2
        bracket    : $bracket_config
        tiebreakers: ["total_points", "champions_correct", "finalists_correct", "earliest_submission"]
      }
    }
  }

  response = $config
  guid = "bk-ht8_iTxZQUXOqjbIIWi7TiS0"
}

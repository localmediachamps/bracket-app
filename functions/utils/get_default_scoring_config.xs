// Returns the default scoring configuration for a tournament (ARCHITECTURE.md section 5).
// championship/consolation map round_number -> points.
// Lookup order for a match: pigtail -> pigtail; placement section -> placement[round_code];
// else section[round_number], falling back to the nearest defined lower round_number, else 1.
// Default versioned scoring config: per-round bracket points plus leaderboard tiebreaker order
function get_default_scoring_config {
  input {
  }

  stack {
    // Championship round_number -> points (rounds 1-6)
    var $championship_points {
      value = {}
        |set:"1":1
        |set:"2":2
        |set:"3":4
        |set:"4":8
        |set:"5":16
        |set:"6":32
    }
  
    // Consolation round_number -> points (rounds 1-8)
    var $consolation_points {
      value = {}
        |set:"1":1
        |set:"2":1
        |set:"3":2
        |set:"4":2
        |set:"5":4
        |set:"6":4
        |set:"7":4
        |set:"8":4
    }
  
    // Placement round_code -> points
    var $placement_points {
      value = {}
        |set:"place_3":4
        |set:"place_5":2
        |set:"place_7":2
    }
  
    // Per-match points by bracket section
    var $bracket_config {
      value = {
        pigtail       : 1
        championship  : $championship_points
        consolation   : $consolation_points
        placement     : $placement_points
        champion_bonus: 0
      }
    }
  
    // Versioned scoring config with tiebreaker order
    var $config {
      value = {
        version    : 1
        bracket    : $bracket_config
        tiebreakers: ["total_points", "champions_correct", "finalists_correct", "earliest_submission"]
      }
    }
  }

  response = $config
}
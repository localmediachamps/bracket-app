// Returns the default pick'em (salary-cap) configuration for a tournament (ARCHITECTURE.md section 7).
// Budget constrains the sum of pick costs (one wrestler per weight class).
// Scoring: placement points for final bracket placement (1st-8th),
// win points per completed win by section, bonus points by victory_type.
// Default pick'em config: budget, seed costs, tiebreaker definitions, and scoring rules
function get_default_pickem_config {
  input {
  }

  stack {
    // Seed -> cost for seeds 1-8
    var $seed_costs {
      value = {}
        |set:"1":200
        |set:"2":160
        |set:"3":140
        |set:"4":120
        |set:"5":100
        |set:"6":90
        |set:"7":80
        |set:"8":70
    }
  
    // Add seeds 9-16 plus the default cost for seeds 17+
    var.update $seed_costs {
      value = $seed_costs
        |set:"9":60
        |set:"10":50
        |set:"11":40
        |set:"12":30
        |set:"13":20
        |set:"14":20
        |set:"15":20
        |set:"16":20
        |set:"default":10
    }
  
    // Final placement (1st-8th) -> points
    var $placement_points {
      value = {}
        |set:"1":16
        |set:"2":12
        |set:"3":10
        |set:"4":9
        |set:"5":8
        |set:"6":7
        |set:"7":6
        |set:"8":5
    }
  
    // Points per completed win by bracket section
    var $win_points {
      value = {}
        |set:"championship":1
        |set:"consolation":0.5
    }
  
    // Bonus points by victory_type
    var $bonus_points {
      value = {}
        |set:"fall":2
        |set:"tech_fall":1.5
        |set:"major":1
    }
  
    // Pick'em scoring rules
    var $scoring {
      value = {
        placement_points: $placement_points
        win_points      : $win_points
        bonus_points    : $bonus_points
      }
    }
  
    // Single tiebreaker definition
    var $tiebreaker_1 {
      value = {
        key  : "tiebreaker_1"
        label: "Tiebreaker 1"
        hint : "Predict the total points earned by all of the wrestlers in your group"
      }
    }
  
    // Full pick'em config
    var $config {
      value = {
        budget     : 1000
        seed_costs : $seed_costs
        tiebreakers: [$tiebreaker_1]
        scoring    : $scoring
      }
    }
  }

  response = $config
}
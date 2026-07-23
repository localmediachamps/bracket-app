// "Bonus percentage" - the share of a wrestler's wins earned by better than
// a plain decision (major decision, tech fall, or fall/pin - the NCAA scoring
// tiers that award a team more than the minimum 3 points a decision gets).
// One of the key stats used to evaluate Hodge Trophy candidates. Returns
// null (not 0) when there are no wins yet, so callers can render "—" instead
// of a misleading 0%.
function compute_bonus_pct {
  input {
    int wins
    int win_major
    int win_tech_fall
    int win_fall
  }

  stack {
    var $bonus_pct { value = null }

    conditional {
      if ($input.wins > 0) {
        var $bonus_wins {
          value = $input.win_major + $input.win_tech_fall + $input.win_fall
        }

        var.update $bonus_pct {
          value = (100 * $bonus_wins / $input.wins)|round
        }
      }
    }
  }

  response = $bonus_pct
  guid = "P6vXtQm3sLbNy8RwZoJh4KcFa7Ug"
}

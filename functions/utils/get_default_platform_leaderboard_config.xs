// Default config for the cross-tournament master leaderboard (see the plan
// doc, "Feature: Master Leaderboard"). No hardcoded values in the scoring
// hooks themselves - everything tunable lives here, same overlay convention
// as get_default_league_config.xs / get_default_pickem_config.xs.
//
// percentile path (bracket/pick'em): points = (percentile ^ curve_exponent)
// * scale. curve_exponent=1 is linear (a 70th-percentile finish is worth
// 70% of scale); raising it rewards top finishes disproportionately more
// without changing what a mid-pack finish is worth.
//
// rubric path (dual-meet-picks - NOT YET BUILT, this just reserves real
// starting values for whenever that mode exists): flat tiers, graded against
// actual results, not against other entrants. dual_meet_scale is deliberately
// expressed as bracket/pickem's own scale times a discount_factor (not an
// independent number) so the two stay linked when scale gets retuned later -
// Garrett's explicit requirement is that high-volume, low-effort dual-meet
// play can never out-rank genuine tournament-prediction skill, which is a
// property of discount_factor, not of the raw tier numbers alone. See the
// plan doc's "Calibration approach" - these starting numbers are a
// placeholder pending a real simulation against a real season's actual
// event-count ratio, not a final answer.
function get_default_platform_leaderboard_config {
  input {
  }

  stack {
    var $percentile {
      value = {
        curve_exponent: 1
        scale         : 100
      }
    }

    var $dual_meet_discount_factor {
      value = 0.4
    }

    var $dual_meet_scale {
      value = $percentile.scale * $dual_meet_discount_factor
    }

    // Tiers keyed by correctness against the weight classes that actually
    // occurred (a predicted weight whose match never happens - e.g. an
    // injury swap - is excluded from both the numerator and denominator
    // entirely, never scored as a miss - see rescore_dual_meet.xs).
    // "perfect_card"/"all_winners" are both zero-missed-winners tiers (the
    // difference is whether every victory-type pick also matched); miss_N
    // keys are picked by (occurred_weight_count - correct_winner_count),
    // so a 9-of-10 card and an 8-of-9 card (one weight nullified) both land
    // on "miss_1" - the rubric grades against what could be predicted, not
    // a fixed field size. 4+ misses falls through to "default".
    var $rubric_tiers {
      value = {}
        |set:"perfect_card":$dual_meet_scale
        |set:"all_winners":($dual_meet_scale * 0.7)
        |set:"miss_1":($dual_meet_scale * 0.5)
        |set:"miss_2":($dual_meet_scale * 0.3)
        |set:"miss_3":($dual_meet_scale * 0.15)
        |set:"default":0
    }

    var $config {
      value = {
        percentile             : $percentile
        dual_meet_discount_factor: $dual_meet_discount_factor
        dual_meet_scale         : $dual_meet_scale
        rubric_tiers            : $rubric_tiers
      }
    }
  }

  response = $config
  guid = "Jt5vRqYo8NwMbXpUeZf3KhL7dSc"
}

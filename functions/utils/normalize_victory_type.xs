// Normalizes a raw wrestler_match_history.victory_type string (scraped text,
// e.g. "Major Decision", "Sudden Victory - 1", "Medical FF w/Loss", "Tie
// Breaker - 2 (Riding Time)") into the canonical lowercase enum used by
// bracket_match.victory_type and the fantasy league's victory_points config:
// decision | major | tech_fall | fall | medical_forfeit | injury_default |
// disqualification | forfeit. Returns null for a void/non-determinative
// result ("No Contest") or genuinely unrecognized text - callers should
// EXCLUDE that match entirely (not count it, not zero-score it), since it
// isn't a real win/loss for either wrestler.
//
// Extends functions/ingest/normalize_candidate.xs's contains-based cascade
// (order matters: medical before forfeit, tech before fall, fall before
// decision) with real-world variants confirmed present in the actual
// imported data (frequency-counted across all 4 scraped seasons,
// 2026-07-22): Sudden Victory/Tie Breaker/Ultimate Tie Breaker (all
// overtime-decided results, functionally a decision unless the raw text
// also says "(Fall)", which the fall check above them already catches),
// "Medical FF w/Loss" (doesn't contain "med"+"for" together - matched here
// on "medical" alone instead), and bare "Default" (treated as
// injury_default, NCAA's usual meaning for an unqualified default).
//
// IMPORTANT: every multi-condition check below pre-computes each `contains`/
// `==` result into its OWN var first, then combines those already-evaluated
// booleans with `||`. Combining two live filter-chain expressions with `||`
// directly in one line (e.g. `$x|contains:"a" || $x|contains:"b"`) was
// confirmed broken in this XanoScript engine (2026-07-22, see debug session)
// - it can silently return the wrong boolean regardless of the actual
// values. Pre-computed-boolean-then-OR is the confirmed-safe pattern.
function normalize_victory_type {
  input {
    text? raw?
  }

  stack {
    var $vt {
      value = ""
    }

    conditional {
      if ($input.raw != null) {
        var.update $vt {
          value = $input.raw|to_lower|trim
        }
      }
    }

    var $victory_type {
      value = null
    }

    conditional {
      if (($vt|strlen) > 0) {
        var $has_medical {
          value = $vt|contains:"medical"
        }

        var $has_inj {
          value = $vt|contains:"inj"
        }

        var $is_default {
          value = $vt == "default"
        }

        var $has_disq {
          value = $vt|contains:"disq"
        }

        var $has_dq {
          value = $vt|contains:"dq"
        }

        var $has_forfeit {
          value = $vt|contains:"forfeit"
        }

        var $is_ff {
          value = $vt == "ff"
        }

        var $starts_for {
          value = $vt|starts_with:"for"
        }

        var $has_tech {
          value = $vt|contains:"tech"
        }

        var $has_fall {
          value = $vt|contains:"fall"
        }

        var $has_pin {
          value = $vt|contains:"pin"
        }

        var $has_maj {
          value = $vt|contains:"maj"
        }

        var $has_dec {
          value = $vt|contains:"dec"
        }

        var $has_sudden_victory {
          value = $vt|contains:"sudden victory"
        }

        var $has_tie_breaker {
          value = $vt|contains:"tie breaker"
        }

        var $has_tiebreaker {
          value = $vt|contains:"tiebreaker"
        }

        var $is_injury_default {
          value = $has_inj || $is_default
        }

        var $is_disqualification {
          value = $has_disq || $has_dq
        }

        var $is_forfeit_a {
          value = $has_forfeit || $is_ff
        }

        var $is_forfeit {
          value = $is_forfeit_a || $starts_for
        }

        var $is_fall {
          value = $has_fall || $has_pin
        }

        var $is_decision_a {
          value = $has_dec || $has_sudden_victory
        }

        var $is_decision_b {
          value = $has_tie_breaker || $has_tiebreaker
        }

        var $is_decision {
          value = $is_decision_a || $is_decision_b
        }

        conditional {
          if ($has_medical) {
            var.update $victory_type {
              value = "medical_forfeit"
            }
          }
          elseif ($is_injury_default) {
            var.update $victory_type {
              value = "injury_default"
            }
          }
          elseif ($is_disqualification) {
            var.update $victory_type {
              value = "disqualification"
            }
          }
          elseif ($is_forfeit) {
            var.update $victory_type {
              value = "forfeit"
            }
          }
          elseif ($has_tech) {
            var.update $victory_type {
              value = "tech_fall"
            }
          }
          elseif ($is_fall) {
            var.update $victory_type {
              value = "fall"
            }
          }
          elseif ($has_maj) {
            var.update $victory_type {
              value = "major"
            }
          }
          elseif ($is_decision) {
            var.update $victory_type {
              value = "decision"
            }
          }
        }
      }
    }
  }

  response = $victory_type
  guid = "jqnCKsQX-X_2JVc76k_z-p30QTo"
}

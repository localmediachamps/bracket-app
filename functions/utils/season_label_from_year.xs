// Converts a season.year (the LATER calendar year of the season span, e.g.
// 2026 for the 2025-26 season) into the "YYYY-YY" label canonical_wrestler_
// team.season_label uses (e.g. "2025-26") - confirmed via the season table's
// own year=2026 row mapping to the "2025-26" active-roster rows. Used to
// restrict draft/autopick/waiver pools to wrestlers who actually rostered
// for THAT specific league's season, not always "whatever's current" - a
// league built around an older season (e.g. a 2025-26 mock/demo league)
// must only offer that season's actual roster, not next year's signees or
// wrestlers who'd already graduated by then.
function season_label_from_year {
  input {
    int year
  }

  stack {
    var $prior_year_text {
      value = ((($input.year) - 1)|to_text)
    }

    var $last_two_digits {
      value = ($input.year|modulus:100)
    }

    var $suffix {
      value = ($last_two_digits < 10) ? ("0" ~ ($last_two_digits|to_text)) : ($last_two_digits|to_text)
    }
  }

  response = ($prior_year_text ~ "-" ~ $suffix)
  guid = "T9wEs2XmQr5NbLpYo7HzFd4GkAj1"
}

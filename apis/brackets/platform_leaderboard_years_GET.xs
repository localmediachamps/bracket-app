// Distinct years present in platform_leaderboard_entry, with entry counts,
// newest first - feeds the Master leaderboard's year switcher so a year
// with real data is never hidden behind an undiscoverable query param.
query "platform/leaderboard/years" verb=GET {
  api_group = "brackets"

  input {
  }

  stack {
    db.query platform_leaderboard_entry {
      return = {type: "list"}
    } as $all_entries

    var $year_counts {
      value = {}
    }

    foreach ($all_entries) {
      each as $e {
        var $ykey {
          value = $e.year|to_text
        }

        var $ycount {
          value = 0
        }

        conditional {
          if ($year_counts|has:$ykey) {
            var.update $ycount {
              value = $year_counts|get:$ykey:0
            }
          }
        }

        var.update $year_counts {
          value = $year_counts|set:$ykey:($ycount + 1)
        }
      }
    }

    var $out {
      value = []
    }

    var $year_keys {
      value = ($year_counts|keys)
    }

    foreach ($year_keys) {
      each as $yk {
        array.push $out {
          value = {year: ($yk|to_int), entries: ($year_counts|get:$yk:0)}
        }
      }
    }

    var $sorted {
      value = $out|sort:"year":"number"|reverse
    }
  }

  response = {
    years: $sorted
  }
  guid = "Q9tXm3RvYs7NcLpWo6HbFd2GkEj4"
}

// Replaces my entire personal ranked list for one weight+season in one
// save - mirrors admin/rankings/{weight}'s exact logic, scoped to $auth.id
// instead of admin-gated.
query "my/rankings/{weight}" verb=PUT {
  api_group = "brackets"
  auth = "user"

  input {
    int weight
    int season_year

    // ordered, top-ranked first
    int[] canonical_wrestler_ids
  }

  stack {
    db.query user_wrestler_ranking {
      where = ($db.user_wrestler_ranking.user_id == $auth.id) && ($db.user_wrestler_ranking.weight == $input.weight) && ($db.user_wrestler_ranking.season_year == $input.season_year)
      return = {type: "list"}
    } as $existing_rows

    var $keep_ids {
      value = {}
    }

    var $rank {
      value = 0
    }

    foreach ($input.canonical_wrestler_ids) {
      each as $cwid {
        math.add $rank {
          value = 1
        }

        var.update $keep_ids {
          value = $keep_ids|set:($cwid|to_text):true
        }

        var $existing {
          value = null
        }

        foreach ($existing_rows) {
          each as $er {
            conditional {
              if ($er.canonical_wrestler_id == $cwid) {
                var.update $existing {
                  value = $er
                }
              }
            }
          }
        }

        conditional {
          if ($existing == null) {
            db.add user_wrestler_ranking {
              data = {
                user_id              : $auth.id
                canonical_wrestler_id: $cwid
                weight               : $input.weight
                season_year          : $input.season_year
                rank                 : $rank
                updated_at           : now
              }
            } as $created
          }
          else {
            conditional {
              if ($existing.rank != $rank) {
                db.edit user_wrestler_ranking {
                  field_name = "id"
                  field_value = $existing.id
                  data = {rank: $rank, updated_at: now}
                } as $updated
              }
            }
          }
        }
      }
    }

    foreach ($existing_rows) {
      each as $er {
        conditional {
          if (($keep_ids|has:($er.canonical_wrestler_id|to_text)) == false) {
            db.del user_wrestler_ranking {
              field_name = "id"
              field_value = $er.id
            }
          }
        }
      }
    }
  }

  response = {
    saved: ($input.canonical_wrestler_ids|count)
  }
  guid = "L8xTn3ZqVs6RyWpBo9HbFd4GkMc1"
}

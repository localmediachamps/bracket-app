// Replaces the entire ranked list for one weight+season in one save - the
// admin UI holds the list locally (drag-to-reorder, add from the pool of
// wrestlers at that weight, remove), then persists the whole ordered list
// at once. rank = array position + 1. Anything previously ranked at this
// weight/season that is not in the new list is removed (dropped from the
// list), everything else is upserted.
query "admin/rankings/{weight}" verb=PUT {
  api_group = "admin"
  auth = "user"

  input {
    int weight
    int season_year

    // ordered, top-ranked first
    int[] canonical_wrestler_ids
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.query wrestler_composite_ranking {
      where = ($db.wrestler_composite_ranking.weight == $input.weight) && ($db.wrestler_composite_ranking.season_year == $input.season_year)
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
            db.add wrestler_composite_ranking {
              data = {
                canonical_wrestler_id: $cwid
                weight               : $input.weight
                season_year          : $input.season_year
                rank                 : $rank
                source_count         : 1
                updated_at           : now
              }
            } as $created
          }
          else {
            conditional {
              if ($existing.rank != $rank) {
                db.edit wrestler_composite_ranking {
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

    // Drop anyone previously ranked here who is no longer in the new list
    foreach ($existing_rows) {
      each as $er {
        conditional {
          if (($keep_ids|has:($er.canonical_wrestler_id|to_text)) == false) {
            db.del wrestler_composite_ranking {
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
  guid = "H4nQz8VtRs6MbYwLp3JcFo7GdXi2"
}

// One-time/occasional bulk-load for wrestler_composite_ranking - upserts a
// batch of {canonical_wrestler_id, weight, rank} rows for a season (used to
// seed from a manually-reviewed external source snapshot, e.g. FloWrestling).
// Upsert on the table's own (canonical_wrestler_id, weight, season_year)
// unique index - safe to re-run.
query "admin/rankings/seed" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    int season_year

    // [{canonical_wrestler_id, weight, rank}]
    json[] rankings
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $created_count { value = 0 }
    var $updated_count { value = 0 }

    foreach ($input.rankings) {
      each as $r {
        db.query wrestler_composite_ranking {
          where = ($db.wrestler_composite_ranking.canonical_wrestler_id == $r.canonical_wrestler_id) && ($db.wrestler_composite_ranking.weight == $r.weight) && ($db.wrestler_composite_ranking.season_year == $input.season_year)
          return = {type: "single"}
        } as $existing

        conditional {
          if ($existing == null) {
            db.add wrestler_composite_ranking {
              data = {
                canonical_wrestler_id: $r.canonical_wrestler_id
                weight               : $r.weight
                season_year          : $input.season_year
                rank                 : $r.rank
                source_count         : 1
                updated_at           : now
              }
            } as $created

            math.add $created_count { value = 1 }
          }
          else {
            db.edit wrestler_composite_ranking {
              field_name = "id"
              field_value = $existing.id
              data = {rank: $r.rank, updated_at: now}
            } as $updated

            math.add $updated_count { value = 1 }
          }
        }
      }
    }
  }

  response = {
    created: $created_count
    updated: $updated_count
  }
  guid = "V3xQm8LtNs5RyWzJo7HbKp2FdCe6"
}

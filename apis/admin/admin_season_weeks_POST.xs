// Bulk-seed a season's week timeline. Admin-only, idempotent on
// (season_id, week_number).
query "admin/season-weeks" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    int season_id

    object[1:40] weeks {
      schema {
        int week_number
        timestamp starts_at
        timestamp ends_at
        text? week_type?=head_to_head filters=trim
        decimal? weight_multiplier?=1
      }
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.get season {
      field_name = "id"
      field_value = $input.season_id
    } as $season

    precondition ($season != null) {
      error_type = "notfound"
      error = "Season not found."
    }

    var $created {
      value = []
    }

    var $skipped {
      value = []
    }

    foreach ($input.weeks) {
      each as $w {
        db.query season_week {
          where = $db.season_week.season_id == $input.season_id && $db.season_week.week_number == $w.week_number
          return = {type: "exists"}
        } as $already_exists

        conditional {
          if ($already_exists) {
            array.push $skipped {
              value = $w.week_number
            }
          }

          else {
            db.add season_week {
              data = {
                created_at        : now
                season_id         : $input.season_id
                week_number       : $w.week_number
                starts_at         : $w.starts_at
                ends_at           : $w.ends_at
                week_type         : $w.week_type|first_notempty:"head_to_head"
                weight_multiplier : $w.weight_multiplier|first_notnull:1
              }
            } as $new_week

            array.push $created {
              value = $new_week
            }
          }
        }
      }
    }
  }

  response = {created: $created, skipped: $skipped}
  guid = "W0-VwNJxHnvSONg3pqhGaG9cg_g"
}

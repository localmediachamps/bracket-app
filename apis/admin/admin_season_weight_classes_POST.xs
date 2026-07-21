// Bulk-seed a season's weight class catalog (the standard 10 NCAA D1
// weights, or whatever set applies). Admin-only, idempotent on
// (season_id, weight) - re-running just skips weights that already exist.
query "admin/season-weight-classes" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    int season_id

    object[1:20] weight_classes {
      schema {
        int weight
        text? name? filters=trim
        int? display_order?
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

    foreach ($input.weight_classes) {
      each as $wc {
        db.query season_weight_class {
          where = $db.season_weight_class.season_id == $input.season_id && $db.season_weight_class.weight == $wc.weight
          return = {type: "exists"}
        } as $already_exists

        conditional {
          if ($already_exists) {
            array.push $skipped {
              value = $wc.weight
            }
          }

          else {
            db.add season_weight_class {
              data = {
                created_at    : now
                season_id     : $input.season_id
                weight        : $wc.weight
                name          : $wc.name
                display_order : $wc.display_order|first_notnull:$wc.weight
              }
            } as $new_wc

            array.push $created {
              value = $new_wc
            }
          }
        }
      }
    }
  }

  response = {created: $created, skipped: $skipped}
  guid = "yr3vBMwqSBn-ryMKHI_3dOCBwmI"
}

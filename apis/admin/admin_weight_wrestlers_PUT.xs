query "admin/weight/{id}/wrestlers" verb=PUT {
  api_group = "Admin"
  description = "Bulk upsert wrestlers for a weight class. Admin only."
  auth = "user"

  input {
    int id {
      description = "Weight class ID"
    }
    json wrestlers {
      description = "Array of wrestler objects: {id?, seed, name, school}"
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin_check

    db.get weight_class {
      field_name  = "id"
      field_value = $input.id
    } as $weight_class

    precondition ($weight_class != null) {
      error_type = "notfound"
      error      = "Weight class not found."
    }

    var $count {
      value = 0
    }

    foreach ($input.wrestlers) {
      each as $wrestler {
        conditional {
          if ($wrestler.id != null) {
            db.edit wrestler {
              field_name  = "id"
              field_value = $wrestler.id
              data        = {
                seed  : $wrestler.seed
                name  : $wrestler.name
                school: $wrestler.school
              }
            } as $updated_wrestler
          }
          else {
            db.add wrestler {
              data = {
                created_at     : now
                tournament_id  : $weight_class.tournament_id
                weight_class_id: $input.id
                seed           : $wrestler.seed
                name           : $wrestler.name
                school         : $wrestler.school
              }
            } as $new_wrestler
          }
        }

        math.add $count {
          value = 1
        }
      }
    }
  }

  response = {updated: $count}
}

query "admin/weight/{id}/initialize-bracket" verb=POST {
  api_group = "Admin"
  description = "Initialize the bracket structure for a weight class. Requires exactly 33 wrestlers. Admin only."
  auth = "user"

  input {
    int id {
      description = "Weight class ID"
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

    function.run initialize_weight_bracket {
      input = {
        weight_class_id: $input.id
        tournament_id  : $weight_class.tournament_id
      }
    } as $result
  }

  response = $result
}

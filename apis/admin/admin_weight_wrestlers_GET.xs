query "admin/weight/{id}/wrestlers" verb=GET {
  api_group = "Admin"
  description = "Get all wrestlers for a weight class, ordered by seed. Admin only."
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

    db.query wrestler {
      where  = $db.wrestler.weight_class_id == $input.id
      sort   = {wrestler.seed: "asc"}
      return = {type: "list"}
    } as $wrestlers
  }

  response = $wrestlers
}

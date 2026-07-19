// Admin bracket view for one weight class (ARCHITECTURE.md section 6:
// GET /admin/tournaments/{id}/bracket/{weightClassId}).
// Same shape as the public bracket view, admin mode: no entry/pick data merged in.
query "admin/tournaments/{id}/bracket/{weightClassId}" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  
    // Weight class ID
    int weightClassId
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get weight_class {
      field_name = "id"
      field_value = $input.weightClassId
    } as $weight_class
  
    precondition ($weight_class != null) {
      error_type = "notfound"
      error = "Weight class not found."
    }
  
    precondition ($weight_class.tournament_id == $input.id) {
      error_type = "inputerror"
      error = "Weight class does not belong to this tournament."
    }
  
    function.run get_weight_bracket_view {
      input = {
        weight_class_id: $input.weightClassId
        tournament_id  : $input.id
      }
    } as $view
  }

  response = $view
}
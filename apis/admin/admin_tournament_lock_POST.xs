// Lock a tournament so no more picks can be made. Admin only.
query "admin/tournament/{id}/lock" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin_check
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    db.edit tournament {
      field_name = "id"
      field_value = $input.id
      data = {status: "locked"}
    } as $updated
  }

  response = $updated
}
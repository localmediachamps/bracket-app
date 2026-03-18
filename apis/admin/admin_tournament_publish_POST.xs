// Publish a draft tournament, making it visible to users. Admin only.
query "admin/tournament/{id}/publish" verb=POST {
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
  
    precondition ($tournament.status == "draft") {
      error_type = "badrequest"
      error = "Only draft tournaments can be published."
    }
  
    db.edit tournament {
      field_name = "id"
      field_value = $input.id
      data = {status: "active"}
    } as $updated
  }

  response = $updated
}
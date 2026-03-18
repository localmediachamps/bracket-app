// Upload a bracket PDF and parse wrestler data using Claude AI. Admin only.
query "admin/weight/{id}/upload-pdf" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Weight class ID
    int id
  
    // Base64-encoded PDF content
    text pdf_base64
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin_check
  
    db.get weight_class {
      field_name = "id"
      field_value = $input.id
    } as $weight_class
  
    precondition ($weight_class != null) {
      error_type = "notfound"
      error = "Weight class not found."
    }
  
    function.run parse_bracket_pdf {
      input = {
        pdf_base64: $input.pdf_base64
      }
    } as $parse_result
  }

  response = $parse_result
}
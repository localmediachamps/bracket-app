// Update a weight class: rename, reorder, template/bracket-size change
// (ARCHITECTURE.md section 6: PUT /admin/weights/{id}).
// Template changes are stored only — regeneration happens explicitly via
// POST /admin/weights/{id}/generate-bracket.
query "admin/weights/{id}" verb=PUT {
  api_group = "admin"
  auth = "user"

  input {
    // Weight class ID
    int id
  
    // New display name
    text? name? filters=trim
  
    // New display order
    int? display_order?
  
    // New bracket template (stored; does NOT regenerate the bracket)
    text? template? filters=trim
  
    // Championship field size (stored; applied on next generation)
    int? bracket_size?
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get weight_class {
      field_name = "id"
      field_value = $input.id
    } as $weight_class
  
    precondition ($weight_class != null) {
      error_type = "notfound"
      error = "Weight class not found."
    }
  
    var $payload {
      value = {}
    }
  
    var.update $payload {
      value = $payload
        |set_ifnotnull:"name":$input.name
        |set_ifnotnull:"display_order":$input.display_order
    }
  
    var.update $payload {
      value = $payload
        |set_ifnotnull:"bracket_template":$input.template
        |set_ifnotnull:"bracket_size":$input.bracket_size
    }
  
    precondition (($payload|keys|count) > 0) {
      error_type = "inputerror"
      error = "No updatable fields provided."
    }
  
    db.patch weight_class {
      field_name = "id"
      field_value = $input.id
      data = $payload
    } as $updated
  }

  response = $updated
}
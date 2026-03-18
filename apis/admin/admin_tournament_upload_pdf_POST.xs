// Upload the full bracket PDF for a tournament. Parses all 10 weight classes at once. Admin only.
query "admin/tournament/{id}/upload-pdf" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  
    // Base64-encoded PDF content
    text pdf_base64
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
  
    // Get all weight classes for this tournament
    db.query weight_class {
      where = $db.weight_class.tournament_id == $input.id
      sort = {weight_class.weight: "asc"}
      return = {type: "list"}
    } as $weight_classes
  
    // Parse the PDF with Claude AI
    function.run parse_bracket_pdf {
      input = {
        pdf_base64       : $input.pdf_base64
        anthropic_api_key: $env.ANTHROPIC_API_KEY
      }
    } as $parse_result
  
    // Save wrestlers for each weight class
    var $saved_count {
      value = 0
    }
  
    foreach ($parse_result.parsed) {
      each as $weight_data {
        // Find the matching weight class record
        db.query weight_class {
          where = $db.weight_class.tournament_id == $input.id && $db.weight_class.weight == $weight_data.weight
          return = {type: "single"}
        } as $wc
      
        conditional {
          if ($wc != null) {
            foreach ($weight_data.wrestlers) {
              each as $wrestler {
                conditional {
                  if ($wrestler.name != null) {
                    db.add wrestler {
                      data = {
                        created_at     : now
                        tournament_id  : $input.id
                        weight_class_id: $wc.id
                        seed           : $wrestler.seed
                        name           : $wrestler.name
                        school         : $wrestler.school
                      }
                    } as $new_wrestler
                  
                    math.add $saved_count {
                      value = 1
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  response = {
    success        : true
    saved_wrestlers: $saved_count
    weights_parsed : $parse_result.parsed
  }
}
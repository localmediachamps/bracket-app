// Upload a bracket PDF for a tournament. Parses all weight classes found in the PDF.
// Creates missing weight classes automatically. Works with any bracket format. Admin only.
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

    // Parse the PDF with Claude AI — discovers weight classes automatically
    function.run parse_bracket_pdf {
      input = {pdf_base64: $input.pdf_base64}
    } as $parse_result

    var $saved_count {
      value = 0
    }

    var $weights_created {
      value = 0
    }

    foreach ($parse_result.parsed) {
      each as $weight_data {
        // Find existing weight class or create it
        db.query weight_class {
          where = $db.weight_class.tournament_id == $input.id && $db.weight_class.weight == $weight_data.weight
          return = {type: "single"}
        } as $found_wc

        conditional {
          if ($found_wc != null) {
            // Weight class exists — save wrestlers directly
            foreach ($weight_data.wrestlers) {
              each as $wrestler {
                conditional {
                  if ($wrestler.name != null) {
                    db.add wrestler {
                      data = {
                        created_at     : now
                        tournament_id  : $input.id
                        weight_class_id: $found_wc.id
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

          else {
            // Weight class doesn't exist — create it then save wrestlers
            db.add weight_class {
              data = {
                created_at   : now
                tournament_id: $input.id
                weight       : $weight_data.weight
                status       : "pending"
              }
            } as $created_wc

            math.add $weights_created {
              value = 1
            }

            foreach ($weight_data.wrestlers) {
              each as $wrestler {
                conditional {
                  if ($wrestler.name != null) {
                    db.add wrestler {
                      data = {
                        created_at     : now
                        tournament_id  : $input.id
                        weight_class_id: $created_wc.id
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
    success         : true
    saved_wrestlers : $saved_count
    weights_created : $weights_created
    weights_parsed  : ($parse_result.parsed|count)
  }
}

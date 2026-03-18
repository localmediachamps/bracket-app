query "admin/tournament/{id}/upload-pdf" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    int id
    text pdf_base64
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin_check
  
    precondition ($input.pdf_base64 != null && $input.pdf_base64 != "") {
      error_type = "inputerror"
      error = "Missing pdf_base64."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    function.run parse_bracket_pdf {
      input = {pdf_base64: $input.pdf_base64}
    } as $parse_result
  
    var $saved_count {
      value = 0
    }
  
    var $weights_created {
      value = 0
    }
  
    db.query weight_class {
      where = $db.weight_class.tournament_id == $input.id
      return = {type: "list"}
    } as $existing_weight_classes
  
    db.query wrestler {
      where = $db.wrestler.tournament_id == $input.id
      return = {type: "list"}
    } as $existing_wrestlers
  
    foreach ($parse_result.parsed) {
      each as $weight_data {
        conditional {
          if ($weight_data.weight != null) {
            var $found_wc {
              value = null
            }
          
            foreach ($existing_weight_classes) {
              each as $wc {
                conditional {
                  if ($wc.weight == $weight_data.weight) {
                    var.update $found_wc {
                      value = $wc
                    }
                  }
                }
              }
            }
          
            conditional {
              if ($found_wc == null) {
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
              
                var.update $found_wc {
                  value = $created_wc
                }
              
                var.update $existing_weight_classes {
                  value = $existing_weight_classes|push:$created_wc
                }
              }
            }
          
            foreach ($weight_data.wrestlers) {
              each as $wrestler {
                conditional {
                  if ($wrestler.name != null && $wrestler.name != "") {
                    var $existing_wrestler {
                      value = null
                    }
                  
                    foreach ($existing_wrestlers) {
                      each as $ew {
                        conditional {
                          if ($ew.weight_class_id == $found_wc.id) {
                            conditional {
                              if ($ew.name == $wrestler.name) {
                                var.update $existing_wrestler {
                                  value = $ew
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  
                    conditional {
                      if ($existing_wrestler == null) {
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
                      
                        var.update $existing_wrestlers {
                          value = $existing_wrestlers|push:$new_wrestler
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
    }
  }

  response = {
    success        : true
    saved_wrestlers: $saved_count
    weights_created: $weights_created
    weights_parsed : $parse_result.parsed|count
  }
}
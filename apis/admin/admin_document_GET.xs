// Document review payload (ARCHITECTURE.md section 6: GET /admin/documents/{id}).
// Returns the uploaded_document row, its extraction_result, and computed validation
// issues: duplicate seeds within a weight, seed gaps (1..N), wrestlers missing a
// school, weight classes with fewer than 2 wrestlers, and duplicate names.
query "admin/documents/{id}" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    // Uploaded document ID
    int id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get uploaded_document {
      field_name = "id"
      field_value = $input.id
    } as $document
  
    precondition ($document != null) {
      error_type = "notfound"
      error = "Document not found."
    }
  
    var $extraction {
      value = $document.extraction_result
    }
  
    var $issues {
      value = []
    }
  
    conditional {
      if ($extraction != null) {
        var $weights {
          value = $extraction|get:"weights":[]
        }
      
        foreach ($weights) {
          each as $w {
            var $wrestlers {
              value = $w|get:"wrestlers":[]
            }
          
            // Weight classes with < 2 wrestlers cannot seed a bracket
            conditional {
              if (($wrestlers|count) < 2) {
                array.push $issues {
                  value = {
                    type   : "insufficient_wrestlers"
                    weight : $w.weight
                    message: "Weight " ~ ($w.weight|to_text) ~ " has fewer than 2 wrestlers."
                  }
                }
              }
            }
          
            var $seeds {
              value = []
            }
          
            var $names {
              value = []
            }
          
            foreach ($wrestlers) {
              each as $wr {
                // Wrestlers missing school
                conditional {
                  if (($wr|get:"school":null) == null || ($wr|get:"school":null) == "") {
                    array.push $issues {
                      value = {
                        type   : "missing_school"
                        weight : $w.weight
                        name   : $wr|get:"name":null
                        message: "Wrestler is missing a school."
                      }
                    }
                  }
                }
              
                // Duplicate names within the weight (case-insensitive)
                conditional {
                  if (($wr|get:"name":null) != null && ($wr|get:"name":null) != "") {
                    var $lower_name {
                      value = ($wr|get:"name":null)|to_lower
                    }
                  
                    conditional {
                      if ($names|some:$$ == $lower_name) {
                        array.push $issues {
                          value = {
                            type   : "duplicate_name"
                            weight : $w.weight
                            name   : $wr|get:"name":null
                            message: "Duplicate wrestler name in this weight."
                          }
                        }
                      }
                    
                      else {
                        array.push $names {
                          value = $lower_name
                        }
                      }
                    }
                  }
                }
              
                // Duplicate seeds within the weight
                conditional {
                  if (($wr|get:"seed":null) != null) {
                    conditional {
                      if ($seeds|some:$$ == ($wr|get:"seed":null)) {
                        array.push $issues {
                          value = {
                            type   : "duplicate_seed"
                            weight : $w.weight
                            seed   : $wr|get:"seed":null
                            name   : $wr|get:"name":null
                            message: "Duplicate seed in this weight."
                          }
                        }
                      }
                    
                      else {
                        array.push $seeds {
                          value = $wr|get:"seed":null
                        }
                      }
                    }
                  }
                }
              }
            }
          
            // Missing seed numbers: gaps in 1..max
            conditional {
              if (($seeds|count) > 0) {
                var $max_seed {
                  value = $seeds|max
                }
              
                for ($max_seed) {
                  each as $idx {
                    var $seed_num {
                      value = $idx + 1
                    }
                  
                    conditional {
                      if (($seeds|some:$$ == $seed_num) == false) {
                        array.push $issues {
                          value = {
                            type   : "missing_seed"
                            weight : $w.weight
                            seed   : $seed_num
                            message: "Seed is missing from this weight."
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
  }

  response = {
    document         : $document
    extraction_result: $extraction
    issues           : $issues
  }
}
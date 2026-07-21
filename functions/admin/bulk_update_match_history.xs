//  Bulk update wrestler_match_history from an uploaded CSV file.
// 
//  The CSV must have headers that match the keys used in the loop:
//  'id' (the record ID), 'score', and 'time_seconds'.
// 
//  Note: With 70k+ records, this operation may hit execution time limits
//  on some plans. If you encounter timeouts, consider batching the CSV
//  into smaller files (e.g., 5,000 to 10,000 rows each).
// 4. Return a summary of the operation.
function bulk_update_match_history {
  input {
    // The uploaded CSV file.
    // CSV file with headers: id, score, time_seconds
    file? csv_file
  }

  stack {
    // 1. Convert the file resource into a raw text string.
    storage.read_file_resource {
      value = $input.csv_file
    } as $csv_text
  
    // 2. Parse the CSV text into an array of objects.
    // This assumes the first row contains headers.
    var $rows {
      value = $csv_text|csv_parse
    }
  
    var $success_count {
      value = 0
    }
  
    var $error_count {
      value = 0
    }
  
    var $errors {
      value = []
    }
  
    // 3. Loop through each row and patch the database.
    foreach ($rows) {
      each as $row {
        try_catch {
          try {
            // Ensure we have a valid integer ID before attempting the edit.
            var $record_id {
              value = $row.id|to_int
            }
          
            // Only proceed if the ID is greater than 0.
            conditional {
              if ($record_id > 0) {
                // Update the matching record in wrestler_match_history.
                // We use db.edit which performs a partial update on the provided data.
                db.edit wrestler_match_history {
                  field_name = "id"
                  field_value = $record_id
                  data = {
                    score       : $row.score
                    time_seconds: $row.time_seconds|to_int
                  }
                } as $updated_row
              
                math.add $success_count {
                  value = 1
                }
              }
            }
          }
        
          catch {
            // Capture errors for debugging (limited to first 100 to avoid bloat).
            math.add $error_count {
              value = 1
            }
          
            conditional {
              if (($errors|count) < 100) {
                var.update $errors {
                  value = $errors
                    |push:{ id: $row.id, message: $error.message }
                }
              }
            }
          }
        }
      }
    }
  }

  response = {
    total_processed: $rows|count
    success        : $success_count
    failed         : $error_count
    errors         : $errors
  }

  guid = "sv2ZGGa21g5hTZ_a8GkuoLQE9BQ"
}
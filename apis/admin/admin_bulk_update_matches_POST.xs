// Admin-only endpoint to bulk update wrestler_match_history via CSV upload.
// Delegates the actual processing to function:bulk_update_match_history.
query "admin/bulk-update-matches" verb=POST {
  api_group = "admin"

  input {
    // MUST be 'file' to populate .path correctly.
    // CSV file with headers: id, score, time_seconds
    file? csv_file
  }

  stack {
    // 1. Verify admin permissions.
    !function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    // 2. Run the bulk update function.
    function.run bulk_update_match_history {
      input = {csv_file: $input.csv_file}
    } as $result
  }

  response = $result
  guid = "W0AZkVhV9Dgj5gbHsK-nmZsjw8s"
}
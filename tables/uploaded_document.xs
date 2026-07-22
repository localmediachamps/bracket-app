table uploaded_document {
  auth = false

  schema {
    int id
    timestamp created_at?=now
  
    // FK to user.id — admin who uploaded
    int uploaded_by
  
    text file_name
  
    // Xano file metadata: {url, path, name, size, type}
    json file
  
    int file_size?
  
    // uploaded | processing | needs_review | confirmed | failed
    text processing_status?=uploaded
  
    // raw AI parse output
    json extraction_result?
  
    text error_message?
  
    // linked tournament after confirm
    int tournament_id?

    // bracket_import (entrant/seed lists, the original flow) | results_import
    // (completed match results, for backfilling an already-decided event -
    // see functions/ai/parse_results_pdf.xs). Existing rows predate this
    // field and are all bracket_import.
    text doc_type?=bracket_import
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "uploaded_by", op: "asc"}]}
    {
      type : "btree"
      field: [{name: "processing_status", op: "asc"}]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
  ]
  guid = "Ljjlhs5WSr-b3Zk5Jui2NUrJha4"
}
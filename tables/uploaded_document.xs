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
}
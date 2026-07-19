// Upload a bracket PDF and run the AI parse inline (ARCHITECTURE.md section 6:
// POST /admin/tournaments/{id}/upload-pdf).
// Stores the file via Xano file storage (storage.create_attachment, same mechanism as
// the previous upload endpoint), creates an uploaded_document row, then calls
// parse_bracket_pdf synchronously. On success the document becomes needs_review with
// the extraction stored; on failure it becomes failed with the error message.
query "admin/tournaments/{id}/upload-pdf" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  
    // The bracket PDF (multipart file field)
    file? pdf_file
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    precondition ($input.pdf_file != null) {
      error_type = "inputerror"
      error = "Missing pdf_file."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    // Xano file storage: attachment metadata ({path, name, size, mime, ...})
    storage.create_attachment {
      value = $input.pdf_file
      access = "public"
      filename = "bracket-" ~ ($input.id|to_text) ~ ".pdf"
    } as $attachment
  
    var $file_name {
      value = $attachment|get:"name":"bracket.pdf"
    }
  
    var $file_size {
      value = $attachment|get:"size":null
    }
  
    db.add uploaded_document {
      data = {
        created_at       : now
        uploaded_by      : $auth.id
        file_name        : $file_name
        file             : $attachment
        file_size        : $file_size
        processing_status: "processing"
        tournament_id    : $input.id
      }
    } as $document
  
    // Public URL consumed by parse_bracket_pdf (URL document source)
    var $pdf_url {
      value = "https://xhuf-7flt-jytp.n7d.xano.io" ~ $attachment.path
    }
  
    var $parse_failed {
      value = false
    }
  
    try_catch {
      try {
        function.run parse_bracket_pdf {
          input = {pdf_url: $pdf_url}
        } as $extraction_result
      
        db.edit uploaded_document {
          field_name = "id"
          field_value = $document.id
          data = {
            processing_status: "needs_review"
            extraction_result: $extraction_result
          }
        } as $document_parsed
      }
    
      catch {
        var.update $parse_failed {
          value = true
        }
      
        db.edit uploaded_document {
          field_name = "id"
          field_value = $document.id
          data = {
            processing_status: "failed"
            error_message    : $error.message
          }
        } as $document_failed
      }
    }
  
    // Re-fetch so the response reflects the final document state
    db.get uploaded_document {
      field_name = "id"
      field_value = $document.id
    } as $final_document
  
    function.run audit {
      input = {
        actor_id   : $auth.id
        entity_type: "uploaded_document"
        entity_id  : $document.id
        action     : "pdf_uploaded"
        new_value  : {
        file_name        : $file_name
        tournament_id    : $input.id
        processing_status: $final_document.processing_status
      }
      }
    } as $audit_row
  }

  response = {
    document_id      : $document.id
    processing_status: $final_document.processing_status
    extraction_result: $final_document.extraction_result
  }
}
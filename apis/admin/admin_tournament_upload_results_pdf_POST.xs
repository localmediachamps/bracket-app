// Upload an official results PDF and run the AI results parse inline -
// sibling to admin/tournaments/{id}/upload-pdf, but for backfilling
// completed match results (see functions/ai/parse_results_pdf.xs's header
// for when this path is appropriate vs normal one-match-at-a-time scoring).
query "admin/tournaments/{id}/upload-results-pdf" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id

    // The results PDF (multipart file field)
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

    storage.create_attachment {
      value = $input.pdf_file
      access = "public"
      filename = "results-" ~ ($input.id|to_text) ~ ".pdf"
    } as $attachment

    var $file_name {
      value = $attachment|get:"name":"results.pdf"
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
        doc_type         : "results_import"
      }
    } as $document

    var $pdf_url {
      value = "https://xhuf-7flt-jytp.n7d.xano.io" ~ $attachment.path
    }

    try_catch {
      try {
        function.run parse_results_pdf {
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

    db.get uploaded_document {
      field_name = "id"
      field_value = $document.id
    } as $final_document

    function.run audit {
      input = {
        actor_id   : $auth.id
        entity_type: "uploaded_document"
        entity_id  : $document.id
        action     : "results_pdf_uploaded"
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
  guid = "CVdnu3VBk7XsiMLru4kzupEaTBg"
}

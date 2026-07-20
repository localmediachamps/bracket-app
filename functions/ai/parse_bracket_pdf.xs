// AI bracket PDF parser (ARCHITECTURE.md section 6: POST /admin/tournaments/{id}/upload-pdf).
// Sends the uploaded PDF to Claude via a URL document source (no base64) and returns
// the structured extraction: tournament metadata plus per-weight wrestler lists.
// Response contract:
//   {tournament_name?, event_date?, location?, weights: [{weight, confidence_note?, wrestlers: [{seed, name, school, record?}]}]}
function parse_bracket_pdf {
  input {
    // Public URL of the uploaded PDF (stored in Xano vault)
    text pdf_url
  }

  stack {
    precondition ($input.pdf_url != null && $input.pdf_url != "") {
      error_type = "inputerror"
      error = "Missing pdf_url."
    }
  
    var $user_prompt {
      value = 'Extract the wrestling tournament bracket data from this PDF. Return ONLY a valid JSON object with no other text, in exactly this format: {"tournament_name":"NCAA Division I Wrestling Championships","event_date":"March 19-21, 2026","location":"Cleveland, OH","weights":[{"weight":125,"confidence_note":"only present when uncertain","wrestlers":[{"seed":1,"name":"First Last","school":"Team Name","record":"24-0"}]}]}. Rules: tournament_name is the event or tournament title when visible at the top of the document, else null. event_date is the event date or date range when visible, else null. location is the venue or city when visible, else null. weight is the integer weight class value in pounds. confidence_note is a short string describing any uncertainty for that weight class (unreadable seeds, cut-off columns, overlapping text); omit the key entirely when you are confident. seed is the wrestler seeding integer, or null if not seeded. name is in First Last format. school is the full team or institution name, or null if unreadable. record is the win-loss record shown next to the wrestler name (for example "24-0"), or null when not shown. Include ALL weight classes found in the PDF and ALL wrestlers in each class. Skip empty entries. Do not assume any fixed number of weight classes or wrestlers per class. Do not omit the seed, name, school, or record keys from wrestler objects.'
    }
  
    // Build URL-based PDF source — Anthropic fetches the file directly, no base64 needed
    var $pdf_source {
      value = {}
        |set:"type":"url"
        |set:"url":$input.pdf_url
    }
  
    var $doc_block {
      value = {}
        |set:"type":"document"
        |set:"source":$pdf_source
    }
  
    var $text_block {
      value = {}
        |set:"type":"text"
        |set:"text":$user_prompt
    }
  
    var $content {
      value = []
    }
  
    array.push $content {
      value = $doc_block
    }
  
    array.push $content {
      value = $text_block
    }
  
    var $message {
      value = {}
        |set:"role":"user"
        |set:"content":$content
    }
  
    var $messages {
      value = []
    }
  
    array.push $messages {
      value = $message
    }
  
    var $request_body {
      value = {}
        |set:"model":"claude-sonnet-5"
        |set:"max_tokens":16000
        |set:"system":"You are a data extraction assistant. You extract wrestling bracket data from PDF documents. Return only valid JSON with no additional text, markdown formatting, or explanation."
        |set:"messages":$messages
    }
  
    api.request {
      url = "https://api.anthropic.com/v1/messages"
      method = "POST"
      params = $request_body
      headers = []
        |push:"x-api-key: " ~ $env.anthropicAPIkey
        |push:"anthropic-version: 2023-06-01"
        |push:"content-type: application/json"
      timeout = 300
    } as $api_response
  
    var $http_status {
      value = $api_response|get:"response.status":null
    }
  
    // SECURITY: never log the full api_response — it contains the request
    // headers (including the API key). Only surface the response error.
    var $api_error_safe {
      value = $api_response|get:"response.error":null
    }
  
    var $api_error_text {
      value = ($api_error_safe|json_encode)|first_notnull:("HTTP status " ~ ($http_status|to_text))
    }
  
    precondition ($http_status != null && $http_status < 400) {
      error_type = "inputerror"
      error = "Claude API request failed: " ~ $api_error_text
    }
  
    var $content_text {
      value = $api_response
        |get:"response.result.content.0.text":null
    }
  
    precondition ($content_text != null && $content_text != "") {
      error_type = "inputerror"
      error = "Claude API returned no content."
    }
  
    // Strip markdown code fences if Claude wrapped the JSON
    var $clean_text {
      value = $content_text
        |regex_replace:"```json":""
        |regex_replace:"```":""
        |trim
    }
  
    // Hardened extraction: isolate the substring from the first { to the last }
    // so leading/trailing prose cannot break json_decode.
    var $open_parts {
      value = $clean_text|split:"{"
    }
  
    precondition (($open_parts|count) > 1) {
      error_type = "inputerror"
      error = "Claude response contained no JSON object. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
    }
  
    var $close_parts {
      value = $clean_text|split:"}"
    }
  
    precondition (($close_parts|count) > 1) {
      error_type = "inputerror"
      error = "Claude response contained no JSON object. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
    }
  
    // Position of the first "{" equals the length of the text before it
    var $first_brace_pos {
      value = ($open_parts|first)|strlen
    }
  
    // Position of the last "}" = total length minus trailing text length minus 1
    var $text_len {
      value = $clean_text|strlen
    }
  
    var $tail_len {
      value = ($close_parts|last)|strlen
    }
  
    var $last_brace_pos {
      value = $text_len - $tail_len - 1
    }
  
    var $json_len {
      value = $last_brace_pos - $first_brace_pos + 1
    }
  
    var $json_text {
      value = $clean_text
        |substr:$first_brace_pos:$json_len
    }
  
    var $parsed {
      value = null
    }
  
    try_catch {
      try {
        var.update $parsed {
          value = $json_text|json_decode
        }
      }
    
      catch {
        precondition (false) {
          error_type = "inputerror"
          error = "Failed to parse Claude response as JSON. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
        }
      }
    }
  
    precondition ($parsed != null) {
      error_type = "inputerror"
      error = "Claude returned null JSON. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
    }
  
    var $weights {
      value = $parsed|get:"weights":null
    }
  
    precondition ($weights != null) {
      error_type = "inputerror"
      error = "Claude JSON did not contain a weights array. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
    }
  
    // Optional tournament-level metadata (null when not visible in the PDF)
    var $tournament_name {
      value = $parsed|get:"tournament_name":null
    }
  
    var $event_date {
      value = $parsed|get:"event_date":null
    }
  
    var $location {
      value = $parsed|get:"location":null
    }
  }

  response = {
    tournament_name: $tournament_name
    event_date     : $event_date
    location       : $location
    weights        : $weights
  }

  history = 100
}
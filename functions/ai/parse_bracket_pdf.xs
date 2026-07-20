// AI bracket PDF parser (ARCHITECTURE.md section 6: POST /admin/tournaments/{id}/upload-pdf).
// Sends the uploaded PDF to OpenAI (Responses API) using the public vault URL as a
// file input and returns the structured extraction: tournament metadata plus
// per-weight wrestler lists.
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
  
    var $file_part {
      value = {}
        |set:"type":"input_file"
        |set:"file_url":$input.pdf_url
    }
  
    var $text_part {
      value = {}
        |set:"type":"input_text"
        |set:"text":$user_prompt
    }
  
    var $content {
      value = []
    }
  
    array.push $content {
      value = $file_part
    }
  
    array.push $content {
      value = $text_part
    }
  
    var $message {
      value = {}
        |set:"role":"user"
        |set:"content":$content
    }
  
    var $input_messages {
      value = []
    }
  
    array.push $input_messages {
      value = $message
    }
  
    var $request_body {
      value = {}
        |set:"model":"gpt-5.5"
        |set:"max_output_tokens":16000
        |set:"instructions":"You are a data extraction assistant. You extract wrestling bracket data from PDF documents. Return only valid JSON with no additional text, markdown formatting, or explanation."
        |set:"input":$input_messages
    }
  
    api.request {
      url = "https://api.openai.com/v1/responses"
      method = "POST"
      params = $request_body
      headers = []
        |push:"Authorization: Bearer " ~ $env.openai_APIKey
        |push:"content-type: application/json"
      timeout = 300
    } as $api_response
  
    var $http_status {
      value = $api_response|get:"response.status":null
    }
  
    // SECURITY: never log the full api_response (request headers carry the key).
    var $api_error_safe {
      value = $api_response|get:"response.error":null
    }
  
    var $api_error_text {
      value = ($api_error_safe|json_encode)|first_notnull:("HTTP status " ~ ($http_status|to_text))
    }
  
    precondition ($http_status != null && $http_status < 400) {
      error_type = "inputerror"
      error = "OpenAI API request failed: " ~ $api_error_text
    }
  
    // Responses API envelope: {output: [{type: "message", content: [{type: "output_text", text: ...}]}]}
    var $output_items {
      value = $api_response
        |get:"response.result.output":null
    }
  
    var $content_text {
      value = null
    }
  
    conditional {
      if ($output_items != null) {
        foreach ($output_items) {
          each as $item {
            conditional {
              if ($content_text == null && ($item|get:"type":null) == "message") {
                var $msg_content {
                  value = $item|get:"content":null
                }
              
                conditional {
                  if ($msg_content != null) {
                    foreach ($msg_content) {
                      each as $block {
                        conditional {
                          if ($content_text == null && ($block|get:"type":null) == "output_text") {
                            var.update $content_text {
                              value = $block|get:"text":null
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
  
    precondition ($content_text != null && $content_text != "") {
      error_type = "inputerror"
      error = "OpenAI API returned no text content. Response envelope (first 400 chars): " ~ (($api_response|get:"response.result":null)|json_encode|substr:0:400)
    }
  
    // The isolation step below already ignores any surrounding prose or code
    // fences, so no regex stripping is needed here (regex_replace was wiping
    // the content to empty).
    var $clean_text {
      value = $content_text|trim
    }
  
    // Hardened extraction: isolate the substring from the first { to the last }
    // so leading/trailing prose cannot break json_decode.
    var $open_parts {
      value = $clean_text|split:"{"
    }
  
    precondition (($open_parts|count) > 1) {
      error_type = "inputerror"
      error = "OpenAI response contained no JSON object. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
    }
  
    var $close_parts {
      value = $clean_text|split:"}"
    }
  
    precondition (($close_parts|count) > 1) {
      error_type = "inputerror"
      error = "OpenAI response contained no JSON object. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
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
          error = "Failed to parse OpenAI response as JSON. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
        }
      }
    }
  
    precondition ($parsed != null) {
      error_type = "inputerror"
      error = "OpenAI returned null JSON. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
    }
  
    var $weights {
      value = $parsed|get:"weights":null
    }
  
    precondition ($weights != null) {
      error_type = "inputerror"
      error = "OpenAI JSON did not contain a weights array. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
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
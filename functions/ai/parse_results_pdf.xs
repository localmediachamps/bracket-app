// AI results PDF parser - sibling to parse_bracket_pdf.xs, but extracts
// completed match RESULTS (who actually won each match and how) instead of
// entrant lists. Used for backfilling an already-decided real event into a
// tournament that's being treated as if it hasn't happened yet (demo/testing
// data), or for correcting/completing results on a live tournament when a
// full official bracket PDF is available - not the normal live-scoring path,
// which enters results one match at a time as they happen.
// Response contract:
//   {weights: [{weight, matches: [{winner_name, loser_name, victory_type, score?, round_label?, bracket_section?}]}]}
function parse_results_pdf {
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
      value = 'Extract every COMPLETED match result from this wrestling bracket PDF. Return ONLY a valid JSON object with no other text, in exactly this format: {"weights":[{"weight":125,"matches":[{"winner_name":"First Last","loser_name":"First Last","victory_type":"decision","score":"6-5","round_label":"First Round","bracket_section":"championship"}]}]}. Rules: weight is the integer weight class value in pounds. Include every weight class found. For every match that has a recorded result (a winner is shown), include one entry with: winner_name and loser_name in "First Last" format (drop seed numbers, team abbreviations, and records - just the wrestler name); victory_type must be exactly one of decision, major, tech_fall, fall, medical_forfeit, injury_default, disqualification, forfeit - map freely-worded results to these (for example "Dec 6-5" or "SV-1 3-2" becomes decision, "MD 12-1" becomes major, "TF-1.5" or "Tech Fall" becomes tech_fall, "Fall" or "Pin" becomes fall, "Med Forfeit" becomes medical_forfeit, "Inj. Default" or "Default" becomes injury_default, "DQ" becomes disqualification, "Forfeit" or "FF" becomes forfeit); score is the numeric score shown (for example "6-5"), or null if not applicable (fall, forfeit, and similar outcomes typically have no numeric score, or a time instead - put the time in score when that is all that is shown, for example "3:42"); round_label is the round name as shown (for example "First Round", "Quarterfinal", "Semifinal", "Championship", "Consolation Round 1", "Third Place Match", "Fifth Place Match", "Seventh Place Match", "Pigtail") or null if unclear; bracket_section is "championship" for the main title bracket, "consolation" for the wrestleback bracket, or "placement" for a true or dual placement match (3rd, 5th, or 7th place). Include BOTH the championship side and the full consolation and wrestleback bracket, every round, not just the final. Skip any match with no recorded winner (not yet wrestled, bye, or unreadable). Do not omit any of the required keys.'
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
        |set:"max_output_tokens":32000
        |set:"instructions":"You are a data extraction assistant. You extract wrestling match results from bracket PDF documents. Return only valid JSON with no additional text, markdown formatting, or explanation."
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

    var $clean_text {
      value = $content_text|trim
    }

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

    var $first_brace_pos {
      value = ($open_parts|first)|strlen
    }

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
  }

  response = {weights: $weights}

  history = 100
  guid = "zAE41Z2joBkdU8eBNHbHis5Zjf4"
}

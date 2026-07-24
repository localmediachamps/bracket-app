// Batch-checks message-board posts for excessive profanity or brand-harming
// content in ONE OpenAI call rather than one call per post - called by
// tasks/audit_board_posts.xs's periodic sweep, not synchronously at post
// creation (that would be far more cost-intensive at real scale; user
// reports are the instant/real-time path instead, see
// apis/board/board_post_report_POST.xs). Mirrors functions/ai/
// parse_results_pdf.xs's request/response-parsing shape.
// Response contract: {results: [{id, flagged, reason}]}
function moderate_board_posts_batch {
  input {
    // [{id, body}] - the batch of not-yet-audited posts to check
    json posts
  }

  stack {
    precondition (($input.posts|count) > 0) {
      error_type = "inputerror"
      error = "posts must be a non-empty array."
    }

    var $user_prompt {
      value = "You are moderating a fantasy wrestling app's message boards for brand safety. Review each post below and flag ONLY posts containing excessive/gratuitous profanity, slurs, harassment, or content that would embarrass the brand if a sponsor or new user saw it. Ordinary trash-talk, competitive banter, and mild swearing are FINE and should NOT be flagged - err toward NOT flagging. Return ONLY a valid JSON object with no other text, in exactly this format: {\"results\":[{\"id\":123,\"flagged\":true,\"reason\":\"short reason\"}]}. Include one entry for EVERY post id given, in any order. reason should be null when flagged is false. Posts to review:\n\n" ~ ($input.posts|json_encode)
    }

    var $request_body {
      value = {}
        |set:"model":"gpt-5.5"
        |set:"max_output_tokens":8000
        |set:"instructions":"You are a content moderation assistant. Return only valid JSON with no additional text, markdown formatting, or explanation."
        |set:"input":$user_prompt
    }

    api.request {
      url = "https://api.openai.com/v1/responses"
      method = "POST"
      params = $request_body
      headers = []
        |push:"Authorization: Bearer " ~ $env.openai_APIKey
        |push:"content-type: application/json"
      timeout = 120
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
      value = $api_response|get:"response.result.output":null
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
      error = "OpenAI API returned no text content."
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
      value = $clean_text|substr:$first_brace_pos:$json_len
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

    var $results {
      value = $parsed|get:"results":null
    }

    precondition ($results != null) {
      error_type = "inputerror"
      error = "OpenAI JSON did not contain a results array. Raw output (first 400 chars): " ~ ($clean_text|substr:0:400)
    }
  }

  response = {results: $results}
  guid = "Mx9pEy5TsAu1VgBqFh7OkZn4IrDc2"
}

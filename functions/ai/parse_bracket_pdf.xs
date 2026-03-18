// Sends a PDF (base64-encoded) to Claude AI and extracts wrestler data per weight class.
// Returns a raw parsed array for admin review — does NOT write to the database.
// Uses Anthropic Messages API with PDF document support (claude-opus-4-6).
function parse_bracket_pdf {
  input {
    // base64-encoded PDF content
    text pdf_base64
  
    // Anthropic API key
    text anthropic_api_key
  }

  stack {
    var $user_prompt {
      value = 'Extract all wrestlers from this NCAA Division I wrestling bracket PDF for all 10 weight classes (125, 133, 141, 149, 157, 165, 174, 184, 197, 285). NCAA DI has 33 qualifiers per weight class, seeded 1-33. Return ONLY a valid JSON object in exactly this format with no other text: {"weights": [{"weight": 125, "wrestlers": [{"seed": 1, "name": "First Last", "school": "University Name"}, ...]}, ...]}. Rules: seed must be integer 1-33, name should be First Last format, school is full institution name, if a seed slot is empty use null for name and school, return exactly 33 entries per weight class.'
    }
  
    // Call Claude API to parse bracket PDF
    api.request {
      url = "https://api.anthropic.com/v1/messages"
      method = "POST"
      params = {
        model     : "claude-opus-4-6"
        max_tokens: 8192
        system    : "You are a data extraction assistant. You extract NCAA Division I wrestling bracket data from PDF documents. Return only valid JSON with no additional text, markdown formatting, or explanation."
        messages  : [
          {
            role: "user"
            content: [
              {
                type: "document"
                source: {
                  type: "base64"
                  media_type: "application/pdf"
                  data: $input.pdf_base64
                }
              }
              {
                type: "text"
                text: $user_prompt
              }
            ]
          }
        ]
      }
    
      headers = []
        |push:"x-api-key: " ~ $input.anthropic_api_key
        |push:"anthropic-version: 2023-06-01"
        |push:"content-type: application/json"
    } as $api_response
  
    var $content_text {
      value = $api_response|get:"content.0.text":null
    }
  
    precondition ($content_text != null) {
      error_type = "inputerror"
      error = "No response content from Claude API. Check API key and PDF format."
    }
  
    var $parsed {
      value = $content_text|json_decode
    }
  
    precondition ($parsed != null && ($parsed|get:"weights":null) != null) {
      error_type = "inputerror"
      error = "Failed to parse Claude response as valid bracket JSON. Please review the raw output and enter data manually."
    }
  }

  response = {
    success   : true
    parsed    : $parsed.weights
    raw_output: $content_text
  }

  history = 100
}
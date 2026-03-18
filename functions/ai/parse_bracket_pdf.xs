// Sends a PDF (base64-encoded) to Claude AI and extracts wrestler data.
// Works with any bracket format — discovers weight classes and participant counts from the PDF.
// Does NOT write to the database.
function parse_bracket_pdf {
  input {
    // base64-encoded PDF content
    text pdf_base64
  }

  stack {
    var $user_prompt {
      value = 'Extract all wrestlers from this wrestling bracket PDF. Identify every weight class present in the document and all participants in each weight class. Return ONLY a valid JSON object in exactly this format with no other text: {"weights": [{"weight": 125, "wrestlers": [{"seed": 1, "name": "First Last", "school": "Team Name"}, ...]}, ...]}. Rules: weight is the integer weight class value in pounds, seed is the wrestler seeding integer (or null if not seeded), name is in First Last format, school is the full team or institution name. Include ALL weight classes found in the PDF and ALL wrestlers in each class. Skip empty entries. Do not assume any fixed number of weight classes or wrestlers per class.'
    }

    // Call Claude API to parse bracket PDF
    api.request {
      url = "https://api.anthropic.com/v1/messages"
      method = "POST"
      params = {
        model     : "claude-opus-4-6"
        max_tokens: 8192
        system    : "You are a data extraction assistant. You extract wrestling bracket data from PDF documents. Return only valid JSON with no additional text, markdown formatting, or explanation."
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
        |push:"x-api-key: " ~ $env.anthropicAPIkey
        |push:"anthropic-version: 2023-06-01"
        |push:"content-type: application/json"
    } as $api_response

    var $content_text {
      value = $api_response|get:"content.0.text":null
    }

    precondition ($content_text != null) {
      error_type = "inputerror"
      error = "Claude API returned no content. Full response: " ~ ($api_response|json_encode)
    }

    var $parsed {
      value = $content_text|json_decode
    }

    precondition ($parsed != null && ($parsed|get:"weights":null) != null) {
      error_type = "inputerror"
      error = "Failed to parse Claude response as JSON. Raw output: " ~ $content_text
    }
  }

  response = {
    success   : true
    parsed    : $parsed.weights
    raw_output: $content_text
  }
}

function parse_bracket_pdf {
  input {
    text pdf_base64
  }

  stack {
    precondition ($input.pdf_base64 != null && $input.pdf_base64 != "") {
      error_type = "inputerror"
      error = "Missing pdf_base64."
    }
  
    var $user_prompt {
      value = 'Extract all wrestlers from this wrestling bracket PDF. Identify every weight class present in the document and all participants in each weight class. Return ONLY a valid JSON object in exactly this format with no other text: {"weights":[{"weight":125,"wrestlers":[{"seed":1,"name":"First Last","school":"Team Name"}]}]}. Rules: weight is the integer weight class value in pounds. seed is the wrestler seeding integer, or null if not seeded. name is in First Last format. school is the full team or institution name, or null if unreadable. Include ALL weight classes found in the PDF and ALL wrestlers in each class. Skip empty entries. Do not assume any fixed number of weight classes or wrestlers per class. Do not omit keys from wrestler objects.'
    }
  
    api.request {
      url = "https://api.anthropic.com/v1/messages"
      method = "POST"
      params = {}
        |set:"model":"claude-opus-4-6"
        |set:"max_tokens":8192
        |set:"system":"You are a data extraction assistant. You extract wrestling bracket data from PDF documents. Return only valid JSON with no additional text, markdown formatting, or explanation."
        |set:"messages":([]
          |push:({}
            |set:"role":"user"
            |set:"content":$user_prompt ~ "\n\nThe following is a base64-encoded PDF source:\n" ~ $input.pdf_base64
          )
        )
      headers = []
        |push:"x-api-key: " ~ $env.anthropicAPIkey
        |push:"anthropic-version: 2023-06-01"
        |push:"content-type: application/json"
      timeout = 120
    } as $api_response
  
    var $http_status {
      value = $api_response|get:"response.status":null
    }
  
    precondition ($http_status != null && $http_status < 400) {
      error_type = "inputerror"
      error = "Claude HTTP error. Full response: " ~ ($api_response|json_encode)
    }
  
    var $api_error_type {
      value = $api_response|get:"response.result.type":null
    }
  
    precondition ($api_error_type != "error") {
      error_type = "inputerror"
      error = `"Claude API error: " ~ ($api_response|get:"response.result.error.message":"Unknown API error")`
    }
  
    var $content_text {
      value = $api_response
        |get:"response.result.content.0.text":null
    }
  
    precondition ($content_text != null && $content_text != "") {
      error_type = "inputerror"
      error = "Claude API returned no content. Full response: " ~ ($api_response|json_encode)
    }
  
    var $parsed {
      value = $content_text|json_decode
    }
  
    precondition ($parsed != null) {
      error_type = "inputerror"
      error = "Failed to parse Claude response as JSON. Raw output: " ~ $content_text
    }
  
    var $weights {
      value = $parsed|get:"weights":null
    }
  
    precondition ($weights != null) {
      error_type = "inputerror"
      error = "Claude JSON did not contain a weights array. Raw output: " ~ $content_text
    }
  }

  response = {
    success   : true
    parsed    : $weights
    raw_output: $content_text
  }

  history = 100
}
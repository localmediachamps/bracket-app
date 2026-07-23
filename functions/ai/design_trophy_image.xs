// Shared trophy-image generation primitive for both tracks (tournament
// library + league builder). Assembles a prompt from structured preset
// choices (not raw user text - keeps output standardized), calls OpenAI's
// Responses API with its built-in image_generation tool, continuing
// previous_response_id when present so an "iterate" call is a real
// conversational follow-up rather than a fresh unrelated generation.
// Stores the result via storage.create_file_resource + create_attachment
// (same vault pattern as auth_avatar_POST.xs, just from base64 instead of
// an upload). Never throws - a failed generation must not block a caller's
// larger flow (tournament completion, builder save); returns
// generation_status: "failed" instead.
function design_trophy_image {
  input {
    // {style, material, color, pillar} preset keys - mapped to descriptive
    // prompt fragments below, not passed to the model as raw text
    json design_inputs

    // 1, 2, or 3
    int placement

    bool? is_marquee?

    // Small optional commissioner/admin freeform refinement note
    text? freeform_note?

    // Responses API continuity token from a prior call - present = iterate
    text? previous_response_id?
  }

  stack {
    var $style { value = $input.design_inputs|get:"style":"classic" }
    var $material { value = $input.design_inputs|get:"material":"gold" }
    var $color { value = $input.design_inputs|get:"color":"gold and black" }
    var $pillar { value = $input.design_inputs|get:"pillar":"tapered column" }

    var $placement_word { value = "3rd place" }

    conditional {
      if ($input.placement == 1) {
        var.update $placement_word { value = "1st place champion" }
      }
      elseif ($input.placement == 2) {
        var.update $placement_word { value = "2nd place" }
      }
    }

    var $prompt {
      value = "A photorealistic, professionally rendered " ~ $placement_word ~ " wrestling trophy. Style: " ~ $style ~ ". Material: " ~ $material ~ ". Color scheme: " ~ $color ~ ". Base/pillar shape: " ~ $pillar ~ ". Studio product photography, centered, plain neutral background, dramatic lighting, no text or lettering anywhere on the trophy."
    }

    conditional {
      if ($input.is_marquee == true) {
        var.update $prompt {
          value = $prompt ~ " This is the marquee national championship trophy - make it noticeably more elaborate and premium than a standard trophy: extra ornamentation, a larger and more detailed figure or emblem, richer materials."
        }
      }
    }

    conditional {
      if ($input.freeform_note != null && ($input.freeform_note|strlen) > 0) {
        var.update $prompt {
          value = $prompt ~ " Additional direction: " ~ $input.freeform_note
        }
      }
    }

    var $request_body {
      value = {}
        |set:"model":"gpt-5.5"
        |set:"tools":[{type: "image_generation"}]
        |set:"input":$prompt
    }

    conditional {
      if ($input.previous_response_id != null && ($input.previous_response_id|strlen) > 0) {
        var.update $request_body {
          value = $request_body|set:"previous_response_id":$input.previous_response_id
        }
      }
    }

    var $image_url { value = null }
    var $response_id { value = null }
    var $generation_status { value = "failed" }
    var $error_message { value = null }

    try_catch {
      try {
        api.request {
          url = "https://api.openai.com/v1/responses"
          method = "POST"
          params = $request_body
          headers = []
            |push:"Authorization: Bearer " ~ $env.openai_APIKey
            |push:"content-type: application/json"
          timeout = 300
        } as $api_response

        var $http_status { value = $api_response|get:"response.status":null }

        precondition ($http_status != null && $http_status < 400) {
          error_type = "standard"
          error = "OpenAI API request failed with status " ~ ($http_status|to_text)
        }

        var.update $response_id { value = $api_response|get:"response.result.id":null }

        var $output_items { value = $api_response|get:"response.result.output":null }
        var $b64_image { value = null }

        conditional {
          if ($output_items != null) {
            foreach ($output_items) {
              each as $item {
                conditional {
                  if ($b64_image == null && ($item|get:"type":null) == "image_generation_call") {
                    var.update $b64_image { value = $item|get:"result":null }
                  }
                }
              }
            }
          }
        }

        precondition ($b64_image != null && ($b64_image|strlen) > 0) {
          error_type = "standard"
          error = "No image_generation_call output found in the response."
        }

        var $image_bytes { value = $b64_image|base64_decode }

        security.create_uuid as $trophy_uuid

        var $filename { value = "trophy-" ~ $trophy_uuid ~ ".png" }

        storage.create_file_resource {
          filename = $filename
          filedata = $image_bytes
        } as $resource

        storage.create_attachment {
          value    = $resource
          access   = "public"
          filename = $filename
        } as $stored_file

        var.update $image_url { value = "https://xhuf-7flt-jytp.n7d.xano.io" ~ $stored_file.path }
        var.update $generation_status { value = "ready" }
      }

      catch {
        var.update $error_message { value = $error.message }
        var.update $generation_status { value = "failed" }
      }
    }
  }

  response = {
    image_url         : $image_url
    prompt_used       : $prompt
    response_id       : $response_id
    generation_status : $generation_status
    error             : $error_message
  }
  guid = "dt4gNP0ktjuUX9SkNtrSWnsp0ZE"
}

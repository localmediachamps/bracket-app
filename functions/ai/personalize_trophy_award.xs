// League-only: takes a locked trophy_template (base design + its
// openai_response_id) and generates a personalized variant with a plaque
// baked in - recipient name, league/event name, and placement rendered
// directly into the image by the model, referencing the template's own
// generation as visual context so the base design carries over unchanged.
// Does NOT mutate the template's own openai_response_id - each
// personalization is a one-off branch off the locked base, so the base
// stays reusable for the next winner. Never throws - same
// generation_status: "failed" contract as design_trophy_image.xs.
function personalize_trophy_award {
  input {
    // Responses API continuity token from the locked base template -
    // required so the personalized variant visually matches it
    text template_response_id
    text recipient_display_name filters=trim
    text league_name filters=trim
    int placement
  }

  stack {
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
      value = "Using this exact trophy design as visual reference, add an engraved plaque or nameplate onto the trophy's base with the following text, clearly legible: \"" ~ $input.recipient_display_name ~ "\" on one line, \"" ~ $input.league_name ~ "\" on the next line, and \"" ~ $placement_word ~ "\" below that. Keep the rest of the trophy design, materials, colors, and composition identical to the reference - only add the engraved text to the base."
    }

    var $request_body {
      value = {}
        |set:"model":"gpt-5.5"
        |set:"tools":[{type: "image_generation"}]
        |set:"input":$prompt
    }

    var.update $request_body {
      value = $request_body|set:"previous_response_id":$input.template_response_id
    }

    var $image_url { value = null }
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

        security.create_uuid as $award_uuid

        var $filename { value = "trophy-award-" ~ $award_uuid ~ ".png" }

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
    image_url        : $image_url
    prompt_used      : $prompt
    generation_status: $generation_status
    error            : $error_message
  }
  guid = "au5MQll9hvV9ZjC2SQQ135l7XY0"
}

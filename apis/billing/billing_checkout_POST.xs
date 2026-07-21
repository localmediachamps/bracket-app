// Creates a Stripe Checkout Session for the annual plan (recurring
// subscription) and returns its hosted URL for the frontend to redirect to.
// success_url/cancel_url come from the frontend (window.location.origin-based)
// rather than a server-side env var, so this never needs code changes if the
// deployed domain changes.
query "billing/checkout" verb=POST {
  api_group = "billing"
  auth = "user"

  input {
    // Where Stripe sends the user back after a successful payment
    text success_url filters=trim

    // Where Stripe sends the user back if they cancel
    text cancel_url filters=trim
  }

  stack {
    precondition ($input.success_url != "" && $input.cancel_url != "") {
      error_type = "inputerror"
      error = "success_url and cancel_url are required."
    }

    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $me

    precondition ($me != null) {
      error_type = "notfound"
      error = "User not found."
    }

    // line_items passed as a nested array directly (api.request's form
    // encoder flattens it into Stripe's bracket notation) - matches the
    // pattern confirmed working in Xano's own official Stripe Checkout
    // extension (installed in this workspace, see api:UQuTJ3vx/sessions).
    var $line_items {
      value = []|push:({}|set:"price":$env.stripe_id_annual|set:"quantity":1)
    }

    var $params {
      value = {}
        |set:"mode":"subscription"
        |set:"line_items":$line_items
        |set:"payment_method_types[0]":"card"
        |set:"success_url":($input.success_url ~ "?checkout=success&session_id={CHECKOUT_SESSION_ID}")
        |set:"cancel_url":($input.cancel_url ~ "?checkout=cancelled")
        |set:"customer_email":$me.email
        |set:"client_reference_id":($auth.id|to_text)
    }

    api.request {
      url = "https://api.stripe.com/v1/checkout/sessions"
      method = "POST"
      params = $params
      headers = []|push:("Authorization: Bearer " ~ $env.stripe_secret_key)
      timeout = 30
    } as $stripe_response

    // api.request's actual response body lives under .response.result -
    // confirmed live against Xano's own official Stripe extension code
    // (sessions_POST.xs), not flat on the top-level variable.
    var $result {
      value = $stripe_response.response.result
    }

    precondition ($result|get:"url":null != null) {
      error_type = "standard"
      error = "Stripe did not return a checkout URL: " ~ ($result|get:"error":{}|get:"message":"unknown error")
    }
  }

  response = {
    checkout_url: $result.url
    session_id  : $result.id
  }
  guid = "GVdxNk6SdMcq_Q6N5uEe_DeansI"
}

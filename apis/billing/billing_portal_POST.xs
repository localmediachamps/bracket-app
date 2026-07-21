// Creates a Stripe Billing Portal session (Stripe-hosted subscription
// management: cancel, update card, etc.) so Mat Savvy doesn't need its own
// subscription-management UI.
query "billing/portal" verb=POST {
  api_group = "billing"
  auth = "user"

  input {
    // Where Stripe sends the user back after they leave the portal
    text return_url filters=trim
  }

  stack {
    precondition ($input.return_url != "") {
      error_type = "inputerror"
      error = "return_url is required."
    }

    db.query subscription {
      where = $db.subscription.user_id == $auth.id
      return = {type: "single"}
    } as $sub

    precondition ($sub != null && $sub.stripe_customer_id != "")  {
      error_type = "notfound"
      error = "No billing account found for this user yet."
    }

    api.request {
      url = "https://api.stripe.com/v1/billing_portal/sessions"
      method = "POST"
      params = {}
        |set:"customer":$sub.stripe_customer_id
        |set:"return_url":$input.return_url
      headers = []|push:("Authorization: Bearer " ~ $env.stripe_secret_key)
      timeout = 30
    } as $stripe_response

    // api.request's actual response body lives under .response.result -
    // confirmed live against Xano's own official Stripe extension code.
    var $result {
      value = $stripe_response.response.result
    }

    precondition ($result|get:"url":null != null) {
      error_type = "standard"
      error = "Stripe did not return a portal URL: " ~ ($result|get:"error":{}|get:"message":"unknown error")
    }
  }

  response = {
    portal_url: $result.url
  }
  guid = "lQGIgEPStPv5uXrjhDo9PfQiUyE"
}

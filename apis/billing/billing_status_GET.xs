// Current user's plan + free-tier submission cap status, for the pricing
// page and account/billing settings.
query "billing/status" verb=GET {
  api_group = "billing"
  auth = "user"

  input {
  }

  stack {
    function.run has_active_entitlement {
      input = {user_id: $auth.id, plan_key: "annual"}
    } as $entitled

    // tournament_id=0 is a harmless placeholder here - we're only reading
    // used/limit/unlimited, not deciding whether a specific submission is
    // allowed, so the already_counted branch never matters for this call.
    function.run check_submission_cap {
      input = {user_id: $auth.id, tournament_id: 0}
    } as $cap

    var $sub {
      value = null
    }

    var $plan {
      value = "free"
    }

    conditional {
      if ($entitled) {
        var.update $plan {
          value = "annual"
        }

        db.query subscription {
          where = ($db.subscription.user_id == $auth.id) && ($db.subscription.plan_key == "annual")
          return = {type: "single"}
        } as $sub_row

        var.update $sub {
          value = $sub_row
        }
      }
    }
  }

  response = {
    plan               : $plan
    entitled           : $entitled
    submissions_used   : $cap.used
    submissions_limit  : $cap.limit
    unlimited          : $cap.unlimited
    subscription_status: $sub|get:"status":null
    current_period_end : $sub|get:"current_period_end":null
  }
  guid = "BztNXHZAuStncIphmtFgU92Kjvw"
}

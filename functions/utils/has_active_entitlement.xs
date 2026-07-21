// Boolean check: does this user have an active paid entitlement for the
// given plan_key? Used to gate fantasy-league creation and to lift the
// free-tier submission cap (see check_submission_cap.xs).
function has_active_entitlement {
  input {
    int user_id

    // e.g. "annual"
    text plan_key
  }

  stack {
    db.query subscription {
      where = ($db.subscription.user_id == $input.user_id) && ($db.subscription.plan_key == $input.plan_key) && ($db.subscription.status == "active")
      return = {type: "single"}
    } as $sub

    var $entitled {
      value = false
    }

    conditional {
      if ($sub != null) {
        conditional {
          if ($sub.current_period_end == null || $sub.current_period_end >= now) {
            var.update $entitled {
              value = true
            }
          }
        }
      }
    }
  }

  response = $entitled
  guid = "gsPhGPcLhIQ_T1i-ayoi7zFNIM0"
}

// Free-tier gate: 3 submitted entries total, lifetime, combined across both
// bracket and pick'em (not per-tournament, not per-season) - counts rows
// with a real submitted_at, not drafts. An active "annual" entitlement lifts
// the cap entirely (unlimited=true). Call before entries_submit_POST.xs /
// pickem_entries_submit_POST.xs actually mark an entry submitted - this
// checks eligibility, it doesn't consume/reserve a slot itself.
function check_submission_cap {
  input {
    int user_id
  }

  stack {
    function.run has_active_entitlement {
      input = {user_id: $input.user_id, plan_key: "annual"}
    } as $unlimited

    var $used {
      value = 0
    }

    conditional {
      if ($unlimited == false) {
        db.query user_bracket {
          where = ($db.user_bracket.user_id == $input.user_id) && ($db.user_bracket.submitted_at != null)
          return = {type: "count"}
        } as $bracket_count

        db.query pickem_entry {
          where = ($db.pickem_entry.user_id == $input.user_id) && ($db.pickem_entry.submitted_at != null)
          return = {type: "count"}
        } as $pickem_count

        var.update $used {
          value = $bracket_count + $pickem_count
        }
      }
    }

    var $limit {
      value = 3
    }

    var $allowed {
      value = true
    }

    conditional {
      if ($unlimited == false && $used >= $limit) {
        var.update $allowed {
          value = false
        }
      }
    }
  }

  response = {
    allowed  : $allowed
    used     : $used
    limit    : $limit
    unlimited: $unlimited
  }
  guid = "HLtQsbKp5Ev_pksDfvBes_Z_XZQ"
}

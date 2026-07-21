// Free-tier gate: 3 DISTINCT TOURNAMENTS with a submission, lifetime -
// bracket + pick'em submitted to the same tournament counts as one, not two
// (a user could submit both game modes for the same event and it still only
// uses one of their 3 slots). Counts rows with a real submitted_at, not
// drafts. An active "annual" entitlement lifts the cap entirely
// (unlimited=true). Call before entries_submit_POST.xs /
// pickem_entries_submit_POST.xs actually mark an entry submitted - this
// checks eligibility, it doesn't consume/reserve a slot itself.
//
// tournament_id is the tournament THIS submission is for - if the user is
// already at the cap but this tournament is already one of their counted
// ones (e.g. adding a pick'em entry to a tournament they already have a
// submitted bracket for), it's still allowed since it doesn't add a new
// distinct tournament.
function check_submission_cap {
  input {
    int user_id
    int tournament_id
  }

  stack {
    function.run has_active_entitlement {
      input = {user_id: $input.user_id, plan_key: "annual"}
    } as $unlimited

    var $used {
      value = 0
    }

    var $already_counted {
      value = false
    }

    conditional {
      if ($unlimited == false) {
        db.query user_bracket {
          where = ($db.user_bracket.user_id == $input.user_id) && ($db.user_bracket.submitted_at != null)
          return = {type: "list"}
          output = ["tournament_id"]
        } as $bracket_entries

        db.query pickem_entry {
          where = ($db.pickem_entry.user_id == $input.user_id) && ($db.pickem_entry.submitted_at != null)
          return = {type: "list"}
          output = ["tournament_id"]
        } as $pickem_entries

        // distinct tournament_ids across both, via a map keyed by id
        var $tournament_map {
          value = {}
        }

        foreach ($bracket_entries) {
          each as $be {
            var.update $tournament_map {
              value = $tournament_map|set:$be.tournament_id:true
            }
          }
        }

        foreach ($pickem_entries) {
          each as $pe {
            var.update $tournament_map {
              value = $tournament_map|set:$pe.tournament_id:true
            }
          }
        }

        var.update $used {
          value = $tournament_map|keys|count
        }

        var.update $already_counted {
          value = $tournament_map|has:$input.tournament_id
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
      if ($unlimited == false && $used >= $limit && $already_counted == false) {
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

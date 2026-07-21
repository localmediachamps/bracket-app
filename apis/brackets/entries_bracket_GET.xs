// Owner-only bracket view for one weight class, with this entry's picks
// merged in (score/HIT-MISS annotations included). Exists because the public
// tournaments/{id}/bracket/{weightClassId} endpoint cannot verify entry_id
// ownership (it has no auth context - see the KNOWN ISSUE note there), so
// personalization is permanently disabled on that path. This endpoint is
// auth-gated to the entry's actual owner instead, using the same inline
// ownership precondition pattern already proven working in
// entries_review_GET.xs (a `function.run verify_entry_ownership` indirection
// was tried first and hit the same masked ERROR_CODE_ACCESS_DENIED as the
// public endpoint's own attempts - inline db.get + precondition avoids it).
query "entries/{id}/bracket/{weightClassId}" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    // Entry id (must belong to the requesting user)
    int id

    // Weight class id
    int weightClassId
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get user_bracket {
      field_name = "id"
      field_value = $input.id
    } as $entry

    precondition ($entry != null) {
      error_type = "notfound"
      error = "Entry not found."
    }

    precondition ($entry.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "You do not own this entry."
    }

    function.run get_weight_bracket_view {
      input = {
        weight_class_id : $input.weightClassId
        tournament_id   : $entry.tournament_id
        entry_id        : $entry.id
        pick_percentages: false
      }
    } as $view
  }

  response = $view
  guid = "K3nRhTqM8LbYw2pXsVdEo4Zc1Nf"
}

// Bracket view for one weight class, with this entry's picks merged in
// (score/HIT-MISS annotations included). Exists because the public
// tournaments/{id}/bracket/{weightClassId} endpoint cannot verify entry_id
// ownership (it has no auth context - see the KNOWN ISSUE note there), so
// personalization is permanently disabled on that path. Viewable by the
// entry's owner, anyone when the entry has opted into is_public, or a site
// admin - same access rule as entries_review_GET.xs (an inline db.get +
// precondition, not a `function.run verify_entry_ownership` indirection,
// since that hit a masked ERROR_CODE_ACCESS_DENIED in earlier testing).
query "entries/{id}/bracket/{weightClassId}" verb=GET {
  api_group = "brackets"

  input {
    // Entry id
    int id

    // Weight class id
    int weightClassId
  }

  stack {
    db.get user_bracket {
      field_name = "id"
      field_value = $input.id
    } as $entry

    precondition ($entry != null) {
      error_type = "notfound"
      error = "Entry not found."
    }

    var $can_view {
      value = ($entry.user_id == $auth.id) || $entry.is_public
    }

    conditional {
      if ($can_view == false && $auth.id != null) {
        db.get user {
          field_name = "id"
          field_value = $auth.id
          output = ["id", "is_admin"]
        } as $requester

        conditional {
          if ($requester != null && $requester.is_admin) {
            var.update $can_view {
              value = true
            }
          }
        }
      }
    }

    precondition ($can_view) {
      error_type = "accessdenied"
      error = "This entry is private."
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

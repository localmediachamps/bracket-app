// One-time wipe for canonical_wrestler (+ its canonical_wrestler_team links).
// Needed because the previous bulk-add run used a broken diagnostic version
// of that endpoint (hardcoded current_team_id/legal_first_name/legal_last_name
// test values instead of real per-wrestler data) - every row it created is
// wrong and needs to be cleared before the corrected re-run. Safe: nothing
// else references canonical_wrestler yet (wrestler_match_history's backfill
// never successfully ran).
query "admin/canonical/wrestlers/wipe" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.query canonical_wrestler_team {
      return = {type: "list"}
    } as $all_links

    var $links_deleted { value = 0 }

    foreach ($all_links) {
      each as $l {
        db.del "canonical_wrestler_team" {
          field_name = "id"
          field_value = $l.id
        }

        math.add $links_deleted { value = 1 }
      }
    }

    db.query canonical_wrestler {
      return = {type: "list"}
    } as $all_wrestlers

    var $wrestlers_deleted { value = 0 }

    foreach ($all_wrestlers) {
      each as $w {
        db.del "canonical_wrestler" {
          field_name = "id"
          field_value = $w.id
        }

        math.add $wrestlers_deleted { value = 1 }
      }
    }
  }

  response = {
    links_deleted    : $links_deleted
    wrestlers_deleted: $wrestlers_deleted
  }
  guid = "Cz8pXnRv3MtGkYqLhWo6BjS4rDf"
}

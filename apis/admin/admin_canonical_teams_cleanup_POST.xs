// One-time cleanup for canonical_team: the initial bulk-add (before the
// D1-only scope was confirmed) indiscriminately created a row for every
// school appearing anywhere in the scraped match history (943 total),
// including non-D1 opponents. This deletes every row whose name isn't in
// the caller-supplied keep list (the real, reconciled 79-team D1 list).
// Safe to run now specifically because canonical_wrestler is still empty -
// no wrestler.current_team_id references exist yet to orphan.
query "admin/canonical/teams/cleanup" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    text[] keep_names
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $keep_map { value = {} }

    foreach ($input.keep_names) {
      each as $n {
        var.update $keep_map { value = $keep_map|set:$n:true }
      }
    }

    db.query canonical_team {
      return = {type: "list"}
    } as $all_teams

    var $deleted_count { value = 0 }
    var $deleted_names { value = [] }
    var $kept_count { value = 0 }

    foreach ($all_teams) {
      each as $t {
        conditional {
          if ($keep_map|has:$t.name) {
            math.add $kept_count { value = 1 }
          }
          else {
            db.del "canonical_team" {
              field_name = "id"
              field_value = $t.id
            }

            math.add $deleted_count { value = 1 }
            array.push $deleted_names { value = $t.name }
          }
        }
      }
    }
  }

  response = {
    total        : $all_teams|count
    kept         : $kept_count
    deleted      : $deleted_count
    deleted_names: $deleted_names
  }
  guid = "Bt6qWmXj2LpFzYvNhSo8CkR5uDe"
}

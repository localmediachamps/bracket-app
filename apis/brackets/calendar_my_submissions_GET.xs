// Which tournaments/dual meets the current user has an actually-submitted
// entry for (bracket, pick'em, or dual meet picks) - feeds the Competition
// Calendar's "you've submitted" badge. Separate from calendar/{} (public,
// no auth) since this needs $auth.id.
query "calendar/my-submissions" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
  }

  stack {
    db.query user_bracket {
      where = ($db.user_bracket.user_id == $auth.id) && ($db.user_bracket.submitted_at != null)
      return = {type: "list"}
    } as $brackets

    db.query pickem_entry {
      where = ($db.pickem_entry.user_id == $auth.id) && ($db.pickem_entry.submitted_at != null)
      return = {type: "list"}
    } as $pickems

    db.query dual_meet_entry {
      where = ($db.dual_meet_entry.user_id == $auth.id) && ($db.dual_meet_entry.submitted_at != null)
      return = {type: "list"}
    } as $dual_meet_entries

    var $tournament_ids {
      value = {}
    }

    foreach ($brackets) {
      each as $b {
        var.update $tournament_ids {
          value = $tournament_ids|set:($b.tournament_id|to_text):true
        }
      }
    }

    foreach ($pickems) {
      each as $p {
        var.update $tournament_ids {
          value = $tournament_ids|set:($p.tournament_id|to_text):true
        }
      }
    }

    var $dual_meet_ids {
      value = {}
    }

    foreach ($dual_meet_entries) {
      each as $d {
        var.update $dual_meet_ids {
          value = $dual_meet_ids|set:($d.dual_meet_id|to_text):true
        }
      }
    }

    var $tournament_id_list {
      value = []
    }

    var $t_keys {
      value = ($tournament_ids|keys)
    }

    foreach ($t_keys) {
      each as $k {
        array.push $tournament_id_list {
          value = ($k|to_int)
        }
      }
    }

    var $dual_meet_id_list {
      value = []
    }

    var $d_keys {
      value = ($dual_meet_ids|keys)
    }

    foreach ($d_keys) {
      each as $k {
        array.push $dual_meet_id_list {
          value = ($k|to_int)
        }
      }
    }
  }

  response = {
    tournament_ids: $tournament_id_list
    dual_meet_ids : $dual_meet_id_list
  }
  guid = "N4vXm8QsBr7YcLpWo3JbFd2GkHi9"
}

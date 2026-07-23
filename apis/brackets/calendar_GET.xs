// Unified, deduplicated schedule of every tournament + dual meet on the
// platform (one row per real event regardless of how many game modes it
// supports) for the Competition Calendar's list/month-grid views. Public -
// submission status is fetched separately (calendar/my-submissions, auth
// required) and cross-referenced client-side, since this endpoint has no
// auth and must work for anonymous visitors too.
query "calendar" verb=GET {
  api_group = "brackets"

  input {
  }

  stack {
    db.query tournament {
      where = $db.tournament.visibility == "public"
      return = {type: "list"}
    } as $tournaments

    db.query dual_meet {
      where = $db.dual_meet.visibility == "public"
      return = {type: "list"}
    } as $dual_meets

    var $events {
      value = []
    }

    foreach ($tournaments) {
      each as $t {
        array.push $events {
          value = {
            type      : "tournament"
            id        : $t.id
            name      : $t.name
            slug      : $t.slug
            year      : $t.year
            start_date: $t.start_date
            end_date  : $t.end_date
            locks_at  : $t.locks_at
            status    : $t.status
          }
        }
      }
    }

    foreach ($dual_meets) {
      each as $d {
        // event_date is the intended field, but a dual meet auto-generated
        // from historical match data only ever gets occurred_at populated -
        // fall back to that so the calendar never shows a real event as
        // undated.
        var $d_date {
          value = $d.event_date
        }

        conditional {
          if ($d_date == null && $d.occurred_at != null) {
            var.update $d_date {
              value = (($d.occurred_at)|format_timestamp:"Y-m-d":"UTC")
            }
          }
        }

        array.push $events {
          value = {
            type      : "dual_meet"
            id        : $d.id
            name      : $d.name
            slug      : $d.slug
            year      : $d.year
            start_date: $d_date
            end_date  : $d_date
            locks_at  : $d.locks_at
            status    : $d.status
          }
        }
      }
    }

    var $sorted {
      value = ($events|sort:"start_date":"text")
    }
  }

  response = {
    events: $sorted
  }
  guid = "T5wRq9XvBs2NcYpLo7HbFd4GkEj8"
}

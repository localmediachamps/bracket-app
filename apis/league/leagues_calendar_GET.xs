// League-scoped calendar: every season_week on this league's season timeline,
// translated into the same {type, name, start_date, status} shape the
// global Competition Calendar uses (calendar_GET.xs) so the frontend can
// reuse the same list/month-grid view components. head_to_head/conference/
// nationals weeks show a generic label (roster-vs-roster, not a single
// dated "event" the way a tournament/dual meet is); marquee_tournament
// weeks show the actual linked tournament's name.
query "leagues/calendar" verb=GET {
  api_group = "league"
  auth = "user"

  input {
    int league_id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get league {
      field_name = "id"
      field_value = $input.league_id
    } as $league

    precondition ($league != null) {
      error_type = "notfound"
      error = "League not found."
    }

    db.query league_membership {
      where = ($db.league_membership.league_id == $input.league_id) && ($db.league_membership.user_id == $auth.id)
      return = {type: "single"}
    } as $membership

    precondition ($membership != null) {
      error_type = "accessdenied"
      error = "You are not a member of this league."
    }

    db.query season_week {
      where = $db.season_week.season_id == $league.season_id
      sort = {season_week.week_number: "asc"}
      return = {type: "list"}
    } as $weeks

    var $events {
      value = []
    }

    foreach ($weeks) {
      each as $w {
        var $label {
          value = "Week " ~ ($w.week_number|to_text) ~ " — Head-to-Head"
        }

        var $tournament_slug {
          value = null
        }

        conditional {
          if ($w.week_type == "conference") {
            var.update $label {
              value = "Week " ~ ($w.week_number|to_text) ~ " — Conference Championship"
            }
          }
          elseif ($w.week_type == "nationals") {
            var.update $label {
              value = "Week " ~ ($w.week_number|to_text) ~ " — Nationals"
            }
          }
          elseif ($w.week_type == "marquee_tournament") {
            var $t_name {
              value = "Marquee Tournament"
            }

            conditional {
              if ($w.linked_tournament_id != null) {
                db.get tournament {
                  field_name = "id"
                  field_value = $w.linked_tournament_id
                  output = ["id", "name", "slug"]
                } as $linked_t

                conditional {
                  if ($linked_t != null) {
                    var.update $t_name {
                      value = $linked_t.name
                    }

                    var.update $tournament_slug {
                      value = $linked_t.slug
                    }
                  }
                }
              }
            }

            var.update $label {
              value = "Week " ~ ($w.week_number|to_text) ~ " — " ~ $t_name
            }
          }
        }

        array.push $events {
          value = {
            type            : "league_week"
            id              : $w.id
            week_type       : $w.week_type
            name            : $label
            start_date      : (($w.starts_at)|format_timestamp:"Y-m-d":"UTC")
            end_date        : (($w.ends_at)|format_timestamp:"Y-m-d":"UTC")
            status          : $w.status
            league_id       : $input.league_id
            tournament_slug : $tournament_slug
          }
        }
      }
    }

    var $sorted {
      value = ($events|sort:"start_date":"text")
    }
  }

  response = {
    league: {id: $league.id, name: $league.name}
    events: $sorted
  }
  guid = "R8xYq3ZtVn6McWpLo9HbFd5GkJi1"
}

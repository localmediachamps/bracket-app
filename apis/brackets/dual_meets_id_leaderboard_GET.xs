// Dual meet leaderboard. Only ranked rows (rank not null), ordered by rank
// ascending. rank_change = prev_rank - rank (positive = moved up). Same
// leaderboard_visible/leaderboard_name_mode opt-out convention as the
// tournament leaderboard.
query "dual-meets/{id}/leaderboard" verb=GET {
  api_group = "brackets"

  input {
    // Dual meet id
    int id

    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    db.get dual_meet {
      field_name = "id"
      field_value = $input.id
    } as $dual_meet

    precondition ($dual_meet != null) {
      error_type = "notfound"
      error = "Dual meet not found."
    }

    var $items {
      value = []
    }

    db.query dual_meet_entry {
      where = $db.dual_meet_entry.dual_meet_id == $input.id && $db.dual_meet_entry.rank != null
      sort = {dual_meet_entry.rank: "asc"}
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $page

    foreach ($page.items) {
      each as $row {
        db.get user {
          field_name = "id"
          field_value = $row.user_id
          output = ["id", "username", "display_name", "avatar_url", "leaderboard_visible", "leaderboard_name_mode"]
        } as $row_user

        conditional {
          if ($row_user.leaderboard_visible == false) {
            continue
          }
        }

        var $row_label {
          value = $row_user.display_name|first_notempty:$row_user.username
        }

        conditional {
          if ($row_user.leaderboard_name_mode == "username") {
            var.update $row_label {
              value = $row_user.username|first_notempty:$row_user.display_name
            }
          }
        }

        var.update $row_user {
          value = $row_user|set:"display_name":$row_label|unset:"leaderboard_visible"|unset:"leaderboard_name_mode"
        }

        var $rank_change {
          value = null
        }

        conditional {
          if (($row.prev_rank != null && $row.rank != null)) {
            var.update $rank_change {
              value = ($row.prev_rank - $row.rank)
            }
          }
        }

        array.push $items {
          value = $row
            |set:"user":$row_user
            |set:"rank_change":$rank_change
        }
      }
    }
  }

  response = {
    items: $items
    total: $page.itemsTotal
    page : $input.page
    per  : $input.per
  }
  guid = "2NvBjlvEPKbinKl-Q083QY3TFvU"
}

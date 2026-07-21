// Every trade (any status) involving my membership in this league, most
// recent first, with the wrestler moving each direction resolved for display.
query "leagues/trades" verb=GET {
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
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id
      return = {type: "single"}
    } as $my_membership

    precondition ($my_membership != null && $my_membership.status == "active") {
      error_type = "accessdenied"
      error = "You are not an active member of this league."
    }

    db.query trade {
      where = $db.trade.league_id == $league.id && ($db.trade.proposer_membership_id == $my_membership.id || $db.trade.receiver_membership_id == $my_membership.id)
      sort = {trade.created_at: "desc"}
      return = {type: "list"}
    } as $trades

    var $trade_rows {
      value = []
    }

    foreach ($trades) {
      each as $t {
        db.query trade_item {
          where = $db.trade_item.trade_id == $t.id
          return = {type: "list"}
        } as $items

        var $item_rows {
          value = []
        }

        foreach ($items) {
          each as $item {
            db.get canonical_wrestler {
              field_name = "id"
              field_value = $item.canonical_wrestler_id
              output = ["id", "display_name"]
            } as $item_wrestler

            array.push $item_rows {
              value = {
                from_membership_id: $item.from_membership_id
                wrestler          : $item_wrestler
              }
            }
          }
        }

        array.push $trade_rows {
          value = {
            trade: $t
            items: $item_rows
          }
        }
      }
    }
  }

  response = $trade_rows
  guid = "oK6dZtgyCF3wlVYkpndBVm6bofw"
}

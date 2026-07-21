// The receiver accepts or rejects a proposed trade. Accepting swaps
// roster_slot ownership atomically for every trade_item and marks the trade
// executed; there's no commissioner veto/review in v1 (plan's open question
// #7 - flagged as a fast-follow, not blocking).
query "leagues/trade/respond" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int trade_id

    // accept | reject
    text action filters=trim|lower
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    precondition ($input.action == "accept" || $input.action == "reject") {
      error_type = "inputerror"
      error = "action must be accept or reject."
    }

    db.get trade {
      field_name = "id"
      field_value = $input.trade_id
    } as $trade

    precondition ($trade != null) {
      error_type = "notfound"
      error = "Trade not found."
    }

    precondition ($trade.status == "proposed") {
      error_type = "inputerror"
      error = "This trade is no longer pending."
    }

    db.get league_membership {
      field_name = "id"
      field_value = $trade.receiver_membership_id
    } as $receiver_membership

    precondition ($receiver_membership != null && $receiver_membership.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "Only the receiving member can respond to this trade."
    }

    var $trade_updated {
      value = null
    }

    conditional {
      if ($input.action == "reject") {
        db.edit trade {
          field_name = "id"
          field_value = $trade.id
          data = {status: "rejected"}
        } as $rejected_trade

        var.update $trade_updated {
          value = $rejected_trade
        }
      }

      else {
        db.query trade_item {
          where = $db.trade_item.trade_id == $trade.id
          return = {type: "list"}
        } as $items

        foreach ($items) {
          each as $item {
            db.get roster_slot {
              field_name = "id"
              field_value = $item.roster_slot_id
            } as $slot

            precondition ($slot != null && $slot.status == "active" && $slot.membership_id == $item.from_membership_id) {
              error_type = "inputerror"
              error = "A roster spot in this trade is no longer valid - it may have been dropped or already traded."
            }
          }
        }

        foreach ($items) {
          each as $item {
            var $new_owner_id {
              value = $trade.proposer_membership_id
            }

            conditional {
              if ($item.from_membership_id == $trade.proposer_membership_id) {
                var.update $new_owner_id {
                  value = $trade.receiver_membership_id
                }
              }
            }

            db.edit roster_slot {
              field_name = "id"
              field_value = $item.roster_slot_id
              data = {membership_id: $new_owner_id, acquired_via: "trade", acquired_at: now}
            } as $moved_slot
          }
        }

        db.edit trade {
          field_name = "id"
          field_value = $trade.id
          data = {status: "executed"}
        } as $executed_trade

        var.update $trade_updated {
          value = $executed_trade
        }
      }
    }

    db.get league_membership {
      field_name = "id"
      field_value = $trade.proposer_membership_id
    } as $proposer_membership

    db.get league {
      field_name = "id"
      field_value = $trade.league_id
    } as $trade_league

    function.run notify {
      input = {
        user_id: $proposer_membership.user_id
        type   : "trade_" ~ $trade_updated.status
        title  : "Your trade in " ~ $trade_league.name ~ " was " ~ $trade_updated.status
        data   : {league_id: $trade.league_id, trade_id: $trade.id}
      }
    } as $notify_result
  }

  response = $trade_updated
  guid = "4CJ52k1nUa8k0kMzhgM1CxuiK8g"
}

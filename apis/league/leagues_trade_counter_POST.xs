// Counter a pending trade offer: the original receiver proposes a new trade
// back (any wrestlers each direction, not necessarily the same ones),
// marking the original "countered" and linking the new one via
// counter_of_trade_id - completing the negotiate lifecycle the `trade`
// table's schema already anticipated (status enum includes "countered",
// counter_of_trade_id exists) but no endpoint ever set. Only the original
// receiver can counter (same as who could accept/reject); the counter's
// receiver is always the original proposer. Chainable - a counter can
// itself be countered.
query "leagues/trade/counter" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int trade_id
    int[] offered_roster_slot_ids
    int[] requested_roster_slot_ids
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get trade {
      field_name = "id"
      field_value = $input.trade_id
    } as $original_trade

    precondition ($original_trade != null) {
      error_type = "notfound"
      error = "Trade not found."
    }

    precondition ($original_trade.status == "proposed") {
      error_type = "inputerror"
      error = "This trade is no longer pending."
    }

    db.get league_membership {
      field_name = "id"
      field_value = $original_trade.receiver_membership_id
    } as $original_receiver

    precondition ($original_receiver != null && $original_receiver.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "Only the receiving member can counter this trade."
    }

    db.get league {
      field_name = "id"
      field_value = $original_trade.league_id
    } as $league

    precondition (($input.offered_roster_slot_ids|count) > 0 && ($input.requested_roster_slot_ids|count) > 0) {
      error_type = "inputerror"
      error = "A trade needs at least one wrestler moving each direction."
    }

    db.get league_membership {
      field_name = "id"
      field_value = $original_trade.proposer_membership_id
    } as $original_proposer

    db.add trade {
      data = {
        created_at             : now
        league_id              : $league.id
        proposer_membership_id : $original_receiver.id
        receiver_membership_id : $original_proposer.id
        status                 : "proposed"
        counter_of_trade_id    : $original_trade.id
      }
    } as $new_trade

    foreach ($input.offered_roster_slot_ids) {
      each as $slot_id {
        db.get roster_slot {
          field_name = "id"
          field_value = $slot_id
        } as $slot

        precondition ($slot != null && $slot.league_id == $league.id && $slot.membership_id == $original_receiver.id && $slot.status == "active") {
          error_type = "inputerror"
          error = "One of your offered roster spots isn't valid."
        }

        db.add trade_item {
          data = {
            created_at           : now
            trade_id             : $new_trade.id
            from_membership_id   : $original_receiver.id
            canonical_wrestler_id: $slot.canonical_wrestler_id
            roster_slot_id       : $slot.id
          }
        } as $offered_item
      }
    }

    foreach ($input.requested_roster_slot_ids) {
      each as $slot_id {
        db.get roster_slot {
          field_name = "id"
          field_value = $slot_id
        } as $slot

        precondition ($slot != null && $slot.league_id == $league.id && $slot.membership_id == $original_proposer.id && $slot.status == "active") {
          error_type = "inputerror"
          error = "One of the requested roster spots isn't valid."
        }

        db.add trade_item {
          data = {
            created_at           : now
            trade_id             : $new_trade.id
            from_membership_id   : $original_proposer.id
            canonical_wrestler_id: $slot.canonical_wrestler_id
            roster_slot_id       : $slot.id
          }
        } as $requested_item
      }
    }

    db.edit trade {
      field_name = "id"
      field_value = $original_trade.id
      data = {status: "countered"}
    } as $updated_original

    function.run notify {
      input = {
        user_id: $original_proposer.user_id
        type   : "trade_countered"
        title  : "You've received a counter-offer in " ~ $league.name
      }
    } as $notify_result
  }

  response = {new_trade: $new_trade, original_trade: $updated_original}
  guid = "8ZwSeJl05ngiT8VsRiTLwDrMZLE"
}

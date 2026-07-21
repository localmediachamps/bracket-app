// Propose a trade: I offer some of my roster_slots, and ask for some of the
// receiver's. Nothing moves until the receiver accepts (leagues_trade_respond_POST).
query "leagues/trade/propose" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int receiver_membership_id
    int[] offered_roster_slot_ids
    int[] requested_roster_slot_ids
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

    db.get league_membership {
      field_name = "id"
      field_value = $input.receiver_membership_id
    } as $receiver_membership

    precondition ($receiver_membership != null && $receiver_membership.league_id == $league.id && $receiver_membership.status == "active") {
      error_type = "inputerror"
      error = "That's not an active member of this league."
    }

    precondition ($receiver_membership.id != $my_membership.id) {
      error_type = "inputerror"
      error = "You can't trade with yourself."
    }

    precondition (($input.offered_roster_slot_ids|count) > 0 && ($input.requested_roster_slot_ids|count) > 0) {
      error_type = "inputerror"
      error = "A trade needs at least one wrestler moving each direction."
    }

    db.add trade {
      data = {
        created_at             : now
        league_id              : $league.id
        proposer_membership_id : $my_membership.id
        receiver_membership_id : $receiver_membership.id
        status                 : "proposed"
      }
    } as $trade

    foreach ($input.offered_roster_slot_ids) {
      each as $slot_id {
        db.get roster_slot {
          field_name = "id"
          field_value = $slot_id
        } as $slot

        precondition ($slot != null && $slot.league_id == $league.id && $slot.membership_id == $my_membership.id && $slot.status == "active") {
          error_type = "inputerror"
          error = "One of your offered roster spots isn't valid."
        }

        db.add trade_item {
          data = {
            created_at          : now
            trade_id             : $trade.id
            from_membership_id   : $my_membership.id
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

        precondition ($slot != null && $slot.league_id == $league.id && $slot.membership_id == $receiver_membership.id && $slot.status == "active") {
          error_type = "inputerror"
          error = "One of the requested roster spots isn't valid."
        }

        db.add trade_item {
          data = {
            created_at          : now
            trade_id             : $trade.id
            from_membership_id   : $receiver_membership.id
            canonical_wrestler_id: $slot.canonical_wrestler_id
            roster_slot_id       : $slot.id
          }
        } as $requested_item
      }
    }

    function.run notify {
      input = {
        user_id: $receiver_membership.user_id
        type   : "trade_proposed"
        title  : "You've received a trade offer in " ~ $league.name
        data   : {league_id: $league.id, trade_id: $trade.id}
      }
    } as $notify_result
  }

  response = $trade
  guid = "dJNvCQidT9BNGmEVvr_4IHSJRIs"
}

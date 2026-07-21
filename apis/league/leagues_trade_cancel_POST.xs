// The proposer withdraws a still-pending trade offer.
query "leagues/trade/cancel" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int trade_id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
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
      field_value = $trade.proposer_membership_id
    } as $proposer_membership

    precondition ($proposer_membership != null && $proposer_membership.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "Only the proposer can cancel this trade."
    }

    db.edit trade {
      field_name = "id"
      field_value = $trade.id
      data = {status: "cancelled"}
    } as $cancelled_trade
  }

  response = $cancelled_trade
  guid = "hnhGwpRtKAMrdAfa5CBo8UxH8MA"
}

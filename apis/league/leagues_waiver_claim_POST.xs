// Claim a waiver-wire wrestler, dropping one of my active roster spots to
// make room. v1 resolves instantly, first-come (the simpler of the two
// options in the plan's open question #5 - batched priority is a fast-follow
// if leagues want it). The claimed wrestler takes over the dropped slot's
// exact type/index so roster shape (10 starters + up to 2 alternates) never
// drifts.
query "leagues/waiver/claim" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    int canonical_wrestler_id
    int drop_roster_slot_id
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

    db.get canonical_wrestler {
      field_name = "id"
      field_value = $input.canonical_wrestler_id
    } as $wrestler

    precondition ($wrestler != null) {
      error_type = "notfound"
      error = "Wrestler not found."
    }

    db.query roster_slot {
      where = $db.roster_slot.league_id == $league.id && $db.roster_slot.canonical_wrestler_id == $input.canonical_wrestler_id && $db.roster_slot.status == "active"
      return = {type: "exists"}
    } as $already_rostered

    precondition ($already_rostered == false) {
      error_type = "inputerror"
      error = "This wrestler is already on a roster in this league."
    }

    db.get roster_slot {
      field_name = "id"
      field_value = $input.drop_roster_slot_id
    } as $drop_slot

    precondition ($drop_slot != null && $drop_slot.league_id == $league.id && $drop_slot.membership_id == $my_membership.id && $drop_slot.status == "active") {
      error_type = "inputerror"
      error = "That roster spot isn't yours to drop."
    }

    db.add waiver_claim {
      data = {
        created_at             : now
        league_id              : $league.id
        membership_id          : $my_membership.id
        canonical_wrestler_id   : $input.canonical_wrestler_id
        season_weight_class_id  : $drop_slot.season_weight_class_id
        drop_roster_slot_id     : $drop_slot.id
        status                  : "awarded"
        submitted_at            : now
      }
    } as $claim

    db.edit roster_slot {
      field_name = "id"
      field_value = $drop_slot.id
      data = {status: "dropped"}
    } as $dropped_slot

    db.add roster_slot {
      data = {
        created_at             : now
        league_id              : $league.id
        membership_id          : $my_membership.id
        canonical_wrestler_id  : $input.canonical_wrestler_id
        season_weight_class_id : $drop_slot.season_weight_class_id
        slot_type              : $drop_slot.slot_type
        slot_index             : $drop_slot.slot_index
        status                 : "active"
        acquired_at            : now
        acquired_via           : "waiver"
      }
    } as $new_slot
  }

  response = {claim: $claim, dropped_slot: $dropped_slot, new_roster_slot: $new_slot}
  guid = "wrY91lFERwC6DCeJUh77fDYPTbw"
}

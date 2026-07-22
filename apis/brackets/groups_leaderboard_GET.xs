// Ranked leaderboard of a fantasy group's active members (delegates to the
// group_leaderboard function). Access mirrors groups/{id} GET's member-list
// gating: public groups are open to anyone, private/unlisted groups require
// the requester to be the owner, an active member, or a site admin - a
// private group's standings must only be visible to its own participants.
query "groups/{id}/leaderboard" verb=GET {
  api_group = "brackets"

  input {
    // Group id
    int id

    // bracket or pickem
    text? mode?=bracket filters=trim|lower

    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    db.get fantasy_group {
      field_name = "id"
      field_value = $input.id
    } as $group

    precondition ($group != null) {
      error_type = "notfound"
      error = "Group not found."
    }

    var $can_view {
      value = $group.privacy == "public"
    }

    conditional {
      if ($can_view == false && $auth.id != null) {
        conditional {
          if ($group.owner_id == $auth.id) {
            var.update $can_view {
              value = true
            }
          }
        }

        conditional {
          if ($can_view == false) {
            db.query group_membership {
              where = $db.group_membership.group_id == $group.id && $db.group_membership.user_id == $auth.id && $db.group_membership.status == "active"
              return = {type: "exists"}
            } as $is_member

            conditional {
              if ($is_member) {
                var.update $can_view {
                  value = true
                }
              }
            }
          }
        }

        conditional {
          if ($can_view == false) {
            db.get user {
              field_name = "id"
              field_value = $auth.id
              output = ["id", "is_admin"]
            } as $admin_check

            conditional {
              if ($admin_check != null && $admin_check.is_admin) {
                var.update $can_view {
                  value = true
                }
              }
            }
          }
        }
      }
    }

    precondition ($can_view) {
      error_type = "accessdenied"
      error = "This group's leaderboard is private."
    }

    function.run group_leaderboard {
      input = {
        group_id: $input.id
        mode    : $input.mode
        page    : $input.page
        per     : $input.per
      }
    } as $board
  }

  response = $board
  guid = "bcLR14w_wB9eYe7VfNa5VU2Vcwo"
}

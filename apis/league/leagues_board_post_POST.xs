// Post a new message to a league's board, or (with parent_post_id) reply to
// an existing post/reply in it - Reddit-style, see tables/board_post.xs. A
// top-level post notifies every OTHER active league member (small, bounded
// audience, unlike the master board - see apis/board/board_post_POST.xs). A
// reply instead notifies only the parent post's author, so replying doesn't
// blast the whole league every time.
query "leagues/board/post" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    text body filters=trim|min:1
    int? parent_post_id?
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
      where = $db.league_membership.league_id == $league.id && $db.league_membership.user_id == $auth.id && $db.league_membership.status == "active"
      return = {type: "exists"}
    } as $is_active_member

    precondition ($is_active_member) {
      error_type = "accessdenied"
      error = "Only active league members can post to this league's message board."
    }

    function.run validate_not_muted {
      input = {user_id: $auth.id}
    } as $poster

    var $parent {
      value = null
    }

    conditional {
      if ($input.parent_post_id != null) {
        db.get board_post {
          field_name = "id"
          field_value = $input.parent_post_id
        } as $parent_lookup

        precondition ($parent_lookup != null && $parent_lookup.league_id == $league.id) {
          error_type = "inputerror"
          error = "That post isn't part of this league's board."
        }

        var.update $parent {
          value = $parent_lookup
        }
      }
    }

    db.add board_post {
      data = {
        league_id      : $league.id
        parent_post_id : $input.parent_post_id
        user_id        : $auth.id
        body           : $input.body
      }
    } as $new_post

    conditional {
      if ($parent != null) {
        db.edit board_post {
          field_name = "id"
          field_value = $parent.id
          data = {reply_count: ($parent.reply_count + 1)}
        } as $updated_parent

        conditional {
          if ($parent.user_id != null && $parent.user_id != $auth.id) {
            function.run notify {
              input = {
                user_id: $parent.user_id
                type   : "league_board_reply"
                title  : $league.name ~ " message board"
                body   : ($poster.display_name|first_notnull:$poster.username) ~ " replied to your message."
                data   : {league_id: $league.id, post_id: $new_post.id, parent_post_id: $parent.id}
              }
            } as $reply_notify_result
          }
        }
      }
      else {
        db.query league_membership {
          where = $db.league_membership.league_id == $league.id && $db.league_membership.status == "active" && $db.league_membership.user_id != $auth.id
          return = {type: "list"}
        } as $other_members

        var $notify_ids {
          value = []
        }

        foreach ($other_members) {
          each as $m {
            array.push $notify_ids {
              value = $m.user_id
            }
          }
        }

        conditional {
          if (($notify_ids|count) > 0) {
            function.run notify {
              input = {
                user_ids: $notify_ids
                type    : "league_board_post"
                title   : $league.name ~ " message board"
                body    : ($poster.display_name|first_notnull:$poster.username) ~ " posted a new message."
                data    : {league_id: $league.id, post_id: $new_post.id}
              }
            } as $notify_result
          }
        }
      }
    }
  }

  response = $new_post
  guid = "Pb2sHC8WvDx4YjEtIk0RnCq7LuGf5"
}

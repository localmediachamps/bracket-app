// Post a new message to a master-board channel, or (with parent_post_id)
// reply to an existing post/reply in it - Reddit-style, see tables/
// board_post.xs. Any authenticated user can post (muted accounts
// excepted). A top-level post does NOT fan out a notification to every
// platform user the way leagues_board_post_POST.xs does for its (small,
// bounded) league membership - that would be extremely noisy at real
// scale. A reply DOES notify the parent post's specific author though -
// that's a targeted, low-volume notification, not a blast.
query "board/post" verb=POST {
  api_group = "board"
  auth = "user"

  input {
    int channel_id
    text body filters=trim|min:1
    int? parent_post_id?
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get board_channel {
      field_name = "id"
      field_value = $input.channel_id
    } as $channel

    precondition ($channel != null && $channel.archived == false) {
      error_type = "notfound"
      error = "Channel not found."
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

        precondition ($parent_lookup != null && $parent_lookup.channel_id == $channel.id) {
          error_type = "inputerror"
          error = "That post isn't part of this channel."
        }

        var.update $parent {
          value = $parent_lookup
        }
      }
    }

    db.add board_post {
      data = {
        channel_id    : $channel.id
        parent_post_id: $input.parent_post_id
        user_id       : $auth.id
        body          : $input.body
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
                type   : "board_reply"
                title  : "New reply"
                body   : ($poster.display_name|first_notnull:$poster.username) ~ " replied to your message."
                data   : {channel_id: $channel.id, post_id: $new_post.id, parent_post_id: $parent.id}
              }
            } as $reply_notify_result
          }
        }
      }
    }
  }

  response = $new_post
  guid = "Ug7xMH3B0Ic9DoJyNp5WsHv2QzLk0"
}

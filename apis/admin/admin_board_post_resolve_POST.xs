// Admin resolves one flagged board_post: restore (false positive, goes
// visible again), delete (confirmed bad, stays hidden, no strike), or
// strike (confirmed bad AND escalates the author's account) - strike 1 = 7
// day mute, strike 2 = 30 day mute, strike 3+ = permanent, per the 3-strike
// rule. Notifies the author on strike so they know why and for how long.
query "admin/board/post/resolve" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    int post_id
    text action filters=trim|lower
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    precondition ($input.action == "restore" || $input.action == "delete" || $input.action == "strike") {
      error_type = "inputerror"
      error = "action must be restore, delete, or strike."
    }

    db.get board_post {
      field_name = "id"
      field_value = $input.post_id
    } as $post

    precondition ($post != null) {
      error_type = "notfound"
      error = "Post not found."
    }

    precondition ($post.moderation_status == "flagged") {
      error_type = "inputerror"
      error = "Only a currently-flagged post can be resolved."
    }

    var $new_status {
      value = "removed"
    }

    conditional {
      if ($input.action == "restore") {
        var.update $new_status {
          value = "visible"
        }
      }
    }

    db.edit board_post {
      field_name = "id"
      field_value = $post.id
      data = {
        moderation_status: $new_status
        reviewed_by      : $auth.id
        reviewed_at      : now
      }
    } as $updated_post

    conditional {
      if ($input.action == "strike" && $post.user_id != null) {
        db.get user {
          field_name = "id"
          field_value = $post.user_id
        } as $author

        conditional {
          if ($author != null) {
            var $now {
              value = now
            }

            var $new_strike_count {
              value = $author.board_strike_count + 1
            }

            var $mute_until {
              value = null
            }

            var $mute_permanently {
              value = false
            }

            var $mute_duration_label {
              value = "7 days"
            }

            conditional {
              if ($new_strike_count <= 1) {
                var.update $mute_until {
                  value = $now + 604800000
                }

                var.update $mute_duration_label {
                  value = "7 days"
                }
              }
              elseif ($new_strike_count == 2) {
                var.update $mute_until {
                  value = $now + 2592000000
                }

                var.update $mute_duration_label {
                  value = "30 days"
                }
              }
              else {
                var.update $mute_permanently {
                  value = true
                }

                var.update $mute_duration_label {
                  value = "permanently"
                }
              }
            }

            db.edit user {
              field_name = "id"
              field_value = $author.id
              data = {
                board_strike_count     : $new_strike_count
                board_muted_until      : $mute_until
                board_muted_permanently: $mute_permanently
              }
            } as $updated_author

            var $mute_phrase {
              value = "for " ~ $mute_duration_label
            }

            conditional {
              if ($mute_permanently) {
                var.update $mute_phrase {
                  value = "permanently"
                }
              }
            }

            var $mute_body {
              value = "A post you made was removed for violating our message board guidelines. You've been muted from posting to message boards " ~ $mute_phrase ~ ". (Strike " ~ ($new_strike_count|to_text) ~ " of 3.)"
            }

            function.run notify {
              input = {
                user_id: $author.id
                type   : "board_muted"
                title  : "Message board posting muted"
                body   : $mute_body
                data   : {strike_count: $new_strike_count, muted_permanently: $mute_permanently}
              }
            } as $notify_result
          }
        }
      }
    }
  }

  response = $updated_post
  guid = "Yk1BRL7F4Mg3HsNcRt9AwLz6UdPo4"
}

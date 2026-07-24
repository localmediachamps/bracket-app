// Report a message-board post as inappropriate - works for BOTH league
// board posts and master-board channel posts, since board_post is shared
// between them. A single report is enough to hide the post immediately
// (moderation_status -> "flagged"), same as an AI flag - erring toward
// protecting other users over protecting against a bad-faith reporter.
// Lands in the same admin review queue as AI-flagged posts (apis/admin/
// admin_board_flagged_GET.xs). One report per (post, reporter) - a second
// report from the same user on the same post is a no-op, not an error.
query "board/post/report" verb=POST {
  api_group = "board"
  auth = "user"

  input {
    int post_id
    text? reason? filters=trim
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get board_post {
      field_name = "id"
      field_value = $input.post_id
    } as $post

    precondition ($post != null) {
      error_type = "notfound"
      error = "Post not found."
    }

    var $can_view {
      value = true
    }

    conditional {
      if ($post.league_id != null) {
        db.query league_membership {
          where = $db.league_membership.league_id == $post.league_id && $db.league_membership.user_id == $auth.id && $db.league_membership.status == "active"
          return = {type: "exists"}
        } as $is_league_member

        var.update $can_view {
          value = $is_league_member
        }
      }
    }

    precondition ($can_view) {
      error_type = "accessdenied"
      error = "You don't have access to this post."
    }

    db.query board_post_report {
      where = $db.board_post_report.post_id == $post.id && $db.board_post_report.reporter_id == $auth.id
      return = {type: "exists"}
    } as $already_reported

    conditional {
      if ($already_reported == false) {
        db.add board_post_report {
          data = {
            post_id    : $post.id
            reporter_id: $auth.id
            reason     : $input.reason
          }
        } as $new_report

        conditional {
          if ($post.moderation_status == "visible") {
            db.edit board_post {
              field_name = "id"
              field_value = $post.id
              data = {
                moderation_status: "flagged"
                flag_reason      : ($input.reason|first_notnull:"Reported by a member.")
                flag_source      : "user_report"
              }
            } as $updated_post
          }
        }
      }
    }
  }

  response = {ok: true}
  guid = "Rd4uJE0YxFz6AlGvKm2TpEs9NwIh7"
}

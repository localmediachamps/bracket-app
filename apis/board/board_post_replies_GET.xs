// Direct replies to one post (league board or master board - board_post is
// shared), oldest first (conversational order, unlike the newest-first main
// feed). Works one level at a time - a reply-to-a-reply is fetched by
// calling this again with that reply's own id, matching how the frontend
// lazily expands a thread rather than eager-loading the whole tree.
query "board/post/replies" verb=GET {
  api_group = "board"
  auth = "user"

  input {
    int post_id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get board_post {
      field_name = "id"
      field_value = $input.post_id
    } as $parent

    precondition ($parent != null) {
      error_type = "notfound"
      error = "Post not found."
    }

    conditional {
      if ($parent.league_id != null) {
        db.query league_membership {
          where = $db.league_membership.league_id == $parent.league_id && $db.league_membership.user_id == $auth.id && $db.league_membership.status == "active"
          return = {type: "exists"}
        } as $is_active_member

        precondition ($is_active_member) {
          error_type = "accessdenied"
          error = "Only active league members can view this thread."
        }
      }
    }

    db.query board_post {
      join = {
        user: {
          table: "user"
          type : "left"
          where: $db.board_post.user_id == $db.user.id
        }
      }

      where = $db.board_post.parent_post_id == $parent.id && $db.board_post.moderation_status == "visible"
      sort = {board_post.created_at: "asc"}
      eval = {
        author_display_name: $db.user.display_name
        author_username    : $db.user.username
        author_avatar_url  : $db.user.avatar_url
      }
      return = {type: "list"}
    } as $replies

    var $replies_with_liked {
      value = []
    }

    foreach ($replies) {
      each as $r {
        db.query board_post_like {
          where = $db.board_post_like.post_id == $r.id && $db.board_post_like.user_id == $auth.id && $db.board_post_like.active == true
          return = {type: "exists"}
        } as $liked_by_me

        array.push $replies_with_liked {
          value = $r|set:"liked_by_me":$liked_by_me
        }
      }
    }
  }

  response = $replies_with_liked
  guid = "Zm2CSN8G5Oh4TiUdRk1AjPq7VwEy8"
}

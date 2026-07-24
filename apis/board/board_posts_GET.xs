// Posts within one master-board channel. Only top-level posts (no
// parent_post_id) - use board/post/replies to fetch a thread's replies
// (Reddit-style). sort picks which denormalized counter drives ranking -
// "recent" (default, newest first), "top" (most liked), or "discussed"
// (most replies) - each is its own db.query with its own DB-level sort, see
// leagues_board_GET.xs for why. Any authenticated user can read.
// Flagged/removed posts never show up here for anyone, including their own
// author.
query "board/posts" verb=GET {
  api_group = "board"
  auth = "user"

  input {
    int channel_id
    text sort?="recent" filters=trim|lower
    int page?=1 filters=min:1
    int per?=50 filters=min:1|max:100
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    precondition ($input.sort == "recent" || $input.sort == "top" || $input.sort == "discussed") {
      error_type = "inputerror"
      error = "sort must be recent, top, or discussed."
    }

    db.get board_channel {
      field_name = "id"
      field_value = $input.channel_id
    } as $channel

    precondition ($channel != null) {
      error_type = "notfound"
      error = "Channel not found."
    }

    var $posts {
      value = null
    }

    conditional {
      if ($input.sort == "top") {
        db.query board_post {
          join = {
            user: {table: "user", type: "left", where: $db.board_post.user_id == $db.user.id}
          }

          where = $db.board_post.channel_id == $channel.id && $db.board_post.moderation_status == "visible" && $db.board_post.parent_post_id == null
          sort = {board_post.like_count: "desc"}
          eval = {
            author_display_name: $db.user.display_name
            author_username    : $db.user.username
            author_avatar_url  : $db.user.avatar_url
          }
          return = {type: "list", paging: {page: $input.page, per_page: $input.per, totals: true}}
        } as $posts_top

        var.update $posts {
          value = $posts_top
        }
      }
      elseif ($input.sort == "discussed") {
        db.query board_post {
          join = {
            user: {table: "user", type: "left", where: $db.board_post.user_id == $db.user.id}
          }

          where = $db.board_post.channel_id == $channel.id && $db.board_post.moderation_status == "visible" && $db.board_post.parent_post_id == null
          sort = {board_post.reply_count: "desc"}
          eval = {
            author_display_name: $db.user.display_name
            author_username    : $db.user.username
            author_avatar_url  : $db.user.avatar_url
          }
          return = {type: "list", paging: {page: $input.page, per_page: $input.per, totals: true}}
        } as $posts_discussed

        var.update $posts {
          value = $posts_discussed
        }
      }
      else {
        db.query board_post {
          join = {
            user: {table: "user", type: "left", where: $db.board_post.user_id == $db.user.id}
          }

          where = $db.board_post.channel_id == $channel.id && $db.board_post.moderation_status == "visible" && $db.board_post.parent_post_id == null
          sort = {board_post.created_at: "desc"}
          eval = {
            author_display_name: $db.user.display_name
            author_username    : $db.user.username
            author_avatar_url  : $db.user.avatar_url
          }
          return = {type: "list", paging: {page: $input.page, per_page: $input.per, totals: true}}
        } as $posts_recent

        var.update $posts {
          value = $posts_recent
        }
      }
    }

    var $items_with_liked {
      value = []
    }

    foreach ($posts.items) {
      each as $p {
        db.query board_post_like {
          where = $db.board_post_like.post_id == $p.id && $db.board_post_like.user_id == $auth.id && $db.board_post_like.active == true
          return = {type: "exists"}
        } as $liked_by_me

        array.push $items_with_liked {
          value = $p|set:"liked_by_me":$liked_by_me
        }
      }
    }
  }

  response = {
    items: $items_with_liked
    total: $posts.itemsTotal
    page : $posts.curPage
    per  : $posts.perPage
  }
  guid = "Tf6wLG2AzHb8CnIxMo4VrGu1PyKj9"
}

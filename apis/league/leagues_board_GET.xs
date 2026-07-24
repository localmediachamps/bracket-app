// League message board - flat chat feed, any active member can read. Only
// top-level posts (no parent_post_id) - use board/post/replies to fetch a
// thread's replies (Reddit-style, see tables/board_post.xs). sort picks
// which denormalized counter drives ranking - "recent" (default, newest
// first), "top" (most liked), or "discussed" (most replies) - each is its
// own db.query with its own DB-level sort, not an in-memory re-sort of a
// recency-fetched page, so "Top"/"Discussed" reflect the whole board, not
// just whatever happened to be newest. Flagged/removed posts never show up
// here for anyone, including their own author - see tables/board_post.xs
// header for the moderation design.
query "leagues/board" verb=GET {
  api_group = "league"
  auth = "user"

  input {
    int league_id
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
      error = "Only active league members can view this league's message board."
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

          where = $db.board_post.league_id == $league.id && $db.board_post.moderation_status == "visible" && $db.board_post.parent_post_id == null
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

          where = $db.board_post.league_id == $league.id && $db.board_post.moderation_status == "visible" && $db.board_post.parent_post_id == null
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

          where = $db.board_post.league_id == $league.id && $db.board_post.moderation_status == "visible" && $db.board_post.parent_post_id == null
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
  guid = "Oa1rGB7VuCw3XiDsHj9QmBp6KtFe4"
}

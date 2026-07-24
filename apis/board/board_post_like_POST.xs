// Toggles the authenticated user's like on a post/reply - works for both
// league board posts and master-board channel posts. Idempotent single
// endpoint (not separate like/unlike routes): liking when not yet liked
// sets it, calling again un-likes it. Keeps board_post.like_count (a
// denormalized counter, not computed at read time) in sync so the feed can
// sort by "Top" - see leagues_board_GET.xs / board_posts_GET.xs.
query "board/post/like" verb=POST {
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

    db.query board_post_like {
      where = $db.board_post_like.post_id == $post.id && $db.board_post_like.user_id == $auth.id
      return = {type: "single"}
    } as $existing_like

    var $now_liked {
      value = true
    }

    var $count_delta {
      value = 1
    }

    conditional {
      if ($existing_like != null) {
        var.update $now_liked {
          value = true
        }

        conditional {
          if ($existing_like.active != null && $existing_like.active == true) {
            var.update $now_liked {
              value = false
            }
          }
        }

        conditional {
          if ($now_liked == false) {
            var.update $count_delta {
              value = -1
            }
          }
        }

        db.edit board_post_like {
          field_name = "id"
          field_value = $existing_like.id
          data = {active: $now_liked}
        } as $updated_like
      }
      else {
        db.add board_post_like {
          data = {
            post_id: $post.id
            user_id: $auth.id
            active : true
          }
        } as $new_like
      }
    }

    db.edit board_post {
      field_name = "id"
      field_value = $post.id
      data = {like_count: ($post.like_count + $count_delta)}
    } as $updated_post
  }

  response = {liked: $now_liked, like_count: $updated_post.like_count}
  guid = "Bp4EUQ0I7Rj6VkWfTm3ClSy9YxDn4"
}

// Delete (soft) a league board post - the post's own author, an active
// commissioner/owner of that league, or a site admin can do this. Separate
// from the AI/user-report moderation flow (apis/admin/
// admin_board_post_resolve_POST.xs) - this is just normal "delete my own
// post" / commissioner housekeeping, never triggers a strike.
query "leagues/board/post/{id}" verb=DELETE {
  api_group = "league"
  auth = "user"

  input {
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get board_post {
      field_name = "id"
      field_value = $input.id
    } as $post

    precondition ($post != null && $post.league_id != null) {
      error_type = "notfound"
      error = "League board post not found."
    }

    db.get user {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "is_admin"]
    } as $requester

    var $is_site_admin {
      value = ($requester != null && $requester.is_admin == true)
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $post.league_id && $db.league_membership.user_id == $auth.id && $db.league_membership.status == "active" && ($db.league_membership.role == "owner" || $db.league_membership.role == "commissioner")
      return = {type: "exists"}
    } as $is_commissioner

    precondition ($post.user_id == $auth.id || $is_commissioner || $is_site_admin) {
      error_type = "accessdenied"
      error = "Only the post's author, a league commissioner, or a site admin can delete this."
    }

    db.edit board_post {
      field_name = "id"
      field_value = $post.id
      data = {
        moderation_status: "removed"
        reviewed_by      : $auth.id
        reviewed_at      : now
      }
    } as $updated_post
  }

  response = {ok: true}
  guid = "Qc3tID9XwEy5ZkFuJl1SoDr8MvHg6"
}

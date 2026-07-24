// Admin review queue - every flagged board_post (from either the AI sweep
// or a user report), oldest first so nothing sits unreviewed indefinitely.
// Covers both league board posts and master-board channel posts in one
// list, joined with author info and (when present) the report count.
query "admin/board/flagged" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.query board_post {
      join = {
        user: {
          table: "user"
          type : "left"
          where: $db.board_post.user_id == $db.user.id
        }
        league: {
          table: "league"
          type : "left"
          where: $db.board_post.league_id == $db.league.id
        }
        channel: {
          table: "board_channel"
          type : "left"
          where: $db.board_post.channel_id == $db.channel.id
        }
      }

      where = $db.board_post.moderation_status == "flagged"
      sort = {board_post.created_at: "asc"}
      eval = {
        author_display_name: $db.user.display_name
        author_username    : $db.user.username
        author_strike_count: $db.user.board_strike_count
        league_name        : $db.league.name
        channel_name       : $db.channel.name
      }
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $posts
  }

  response = {
    items: $posts.items
    total: $posts.itemsTotal
    page : $posts.curPage
    per  : $posts.perPage
  }
  guid = "Xj0AQK6E3Lf2GrMbQs8ZvKy5TcOn3"
}

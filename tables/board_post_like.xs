// One row per (post, user) - a like on a message-board post or reply.
// Soft-toggled via `active` rather than ever deleted (matches this
// project's established soft-delete convention, and avoids needing db.
// delete) - liking sets active=true, unliking sets it back to false on the
// SAME row rather than removing it. board_post.like_count is the
// denormalized source of truth for display/sorting; this table exists to
// know whether THIS user has already liked a given post (so the toggle
// button shows the right state) and to make the count auditable/reversible.
table board_post_like {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? post_id? {
      table = "board_post"
    }

    int? user_id? {
      table = "user"
    }

    bool active?=true
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "post_id", op: "asc"}, {name: "user_id", op: "asc"}]}
  ]
  guid = "Ao3DTP9H6Qi5UjVeSl2BkRx8XwCm3"
}

// One row per message-board post, shared by both board types this app has:
// a per-league board (league_id set, channel_id null - any active league
// member can read/post) and the platform-wide master board (channel_id set,
// league_id null - any authenticated user can read/post within a channel).
// Exactly one of league_id/channel_id is ever set on a given row.
//
// Replies (2026-07-24): parent_post_id makes a post a reply to another post
// in the SAME board (Reddit-style) - a reply's own league_id/channel_id is
// copied from its parent at creation time rather than taken from the
// request, so a reply can never end up detached in a different board than
// its parent. Self-referencing FK, so nesting (a reply to a reply) works
// for free at the data level; apis/board/board_post_replies_GET.xs fetches
// one post's direct replies in creation order.
//
// like_count/reply_count are DENORMALIZED counters (not computed at read
// time via a subquery) specifically so the main feed can sort natively by
// them ("Top"/"Most discussed", see leagues_board_GET.xs / board_posts_GET.
// xs's sort input) - a real db column sorts far better than a per-row count
// subquery. Kept in sync by board_post_like_POST.xs (like_count) and the
// post-creation endpoints incrementing their parent's reply_count.
//
// Moderation (2026-07-24): two independent paths can flag a post -
// (1) any user reporting it (see board_post_report - one report is enough,
// hides the post immediately) and (2) a periodic scheduled AI sweep of
// not-yet-audited posts (tasks/audit_board_posts.xs - batches many posts
// into one AI call rather than checking synchronously at post time, since
// that would be far more cost-intensive at scale). Both paths converge on
// the same moderation_status + admin review queue
// (apis/admin/admin_board_flagged_GET.xs /
// admin_board_post_resolve_POST.xs) - a flagged post is hidden from
// everyone (including its own author) the instant it's flagged, never a
// gradual/threshold thing.
table board_post {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? league_id? {
      table = "league"
    }

    int? channel_id? {
      table = "board_channel"
    }

    int? parent_post_id? {
      table = "board_post"
    }

    int? user_id? {
      table = "user"
    }

    text body filters=trim

    int like_count?=0
    int reply_count?=0

    enum moderation_status?="visible" {
      values = ["visible", "flagged", "removed"]
    }

    // Why it was flagged - AI's stated reason, or "Reported by a member."
    // for user reports. Shown to admins in the review queue, not to users.
    text? flag_reason?

    enum? flag_source? {
      values = ["ai", "user_report"]
    }

    // Has the periodic AI sweep already looked at this post? Prevents
    // re-auditing the same post every run - set true whether or not it
    // ends up flagged.
    bool ai_reviewed?=false

    int? reviewed_by? {
      table = "user"
    }

    timestamp? reviewed_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "league_id", op: "asc"}, {name: "created_at", op: "desc"}]}
    {type: "btree", field: [{name: "channel_id", op: "asc"}, {name: "created_at", op: "desc"}]}
    {type: "btree", field: [{name: "parent_post_id", op: "asc"}, {name: "created_at", op: "asc"}]}
    {type: "btree", field: [{name: "moderation_status", op: "asc"}]}
    {type: "btree", field: [{name: "ai_reviewed", op: "asc"}]}
    {type: "btree", field: [{name: "like_count", op: "desc"}]}
    {type: "btree", field: [{name: "reply_count", op: "desc"}]}
  ]
  guid = "Kv7nCw3RqYs9TeZoDf5MiXl2GpBa0"
}

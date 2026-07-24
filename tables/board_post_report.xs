// One row per (post, reporter) - a member flagging a board_post as
// inappropriate. Any single report immediately hides the post (sets
// board_post.moderation_status = "flagged") pending admin review - see
// apis/board/board_post_report_POST.xs. Unique per (post_id, reporter_id)
// so one user can't spam multiple reports on the same post; multiple
// DIFFERENT users can each report the same post, which is useful signal
// for the admin reviewing it even though the first report already hid it.
table board_post_report {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? post_id? {
      table = "board_post"
    }

    int? reporter_id? {
      table = "user"
    }

    text? reason? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "post_id", op: "asc"}, {name: "reporter_id", op: "asc"}]}
  ]
  guid = "Lw8oDx4SrZt0UfApEg6NjYm3HqCb1"
}

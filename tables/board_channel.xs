// Admin-managed channels for the platform-wide "master" message board
// (Discord/Slack-style) - regular users read/post within a channel but
// never create/edit/archive one themselves, only admins do (see
// apis/admin/admin_board_channels_*.xs).
table board_channel {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    text name filters=trim
    text slug filters=trim|lower
    text description? filters=trim

    int sort_order?=0
    bool archived?=false

    int? created_by? {
      table = "user"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "slug", op: "asc"}]}
    {type: "btree", field: [{name: "sort_order", op: "asc"}]}
  ]
  guid = "Jt6mBv2QpXr8SdYnCe4LhWk1FoAz9"
}

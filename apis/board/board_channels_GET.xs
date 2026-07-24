// List channels for the platform-wide master message board. Any
// authenticated user can read - only site admins create/edit/archive
// channels (apis/admin/admin_board_channels_*.xs).
query "board/channels" verb=GET {
  api_group = "board"
  auth = "user"

  input {
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.query board_channel {
      where = $db.board_channel.archived == false
      sort = {board_channel.sort_order: "asc"}
      return = {type: "list"}
    } as $channels
  }

  response = $channels
  guid = "Se5vKF1ZyGa7BmHwLn3UqFt0OxJi8"
}

// Admin creates a new master-board channel (Discord/Slack-style). Slug is
// derived from name if not given, and must be unique.
query "admin/board/channels" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    text name filters=trim|min:1
    text? slug? filters=trim|lower
    text? description? filters=trim
    int sort_order?=0
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    function.run slugify {
      input = {text: ($input.slug|first_notnull:$input.name)}
    } as $final_slug

    db.query board_channel {
      where = $db.board_channel.slug == $final_slug
      return = {type: "exists"}
    } as $slug_taken

    precondition ($slug_taken == false) {
      error_type = "inputerror"
      error = "A channel with that slug already exists."
    }

    db.add board_channel {
      data = {
        name       : $input.name
        slug       : $final_slug
        description: $input.description
        sort_order : $input.sort_order
        created_by : $auth.id
      }
    } as $new_channel
  }

  response = $new_channel
  guid = "Vh8yNI4C1Jd0EpKzOq6XtIw3RaMl1"
}

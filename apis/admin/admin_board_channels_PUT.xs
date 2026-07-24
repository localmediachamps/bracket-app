// Admin edits or archives a master-board channel. Archiving hides it from
// the channel list and blocks new posts, but existing posts/history stay
// intact (never deleted).
query "admin/board/channels/{id}" verb=PUT {
  api_group = "admin"
  auth = "user"

  input {
    int id
    text? name? filters=trim|min:1
    text? description? filters=trim
    int? sort_order?
    bool? archived?
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.get board_channel {
      field_name = "id"
      field_value = $input.id
    } as $channel

    precondition ($channel != null) {
      error_type = "notfound"
      error = "Channel not found."
    }

    var $payload {
      value = {}
    }

    conditional {
      if ($input.name != null) {
        var.update $payload {
          value = $payload|set:"name":$input.name
        }
      }
    }

    conditional {
      if ($input.description != null) {
        var.update $payload {
          value = $payload|set:"description":$input.description
        }
      }
    }

    conditional {
      if ($input.sort_order != null) {
        var.update $payload {
          value = $payload|set:"sort_order":$input.sort_order
        }
      }
    }

    conditional {
      if ($input.archived != null) {
        var.update $payload {
          value = $payload|set:"archived":$input.archived
        }
      }
    }

    db.patch board_channel {
      field_name = "id"
      field_value = $channel.id
      data = $payload
    } as $updated_channel
  }

  response = $updated_channel
  guid = "Wi9zOJ5D2Ke1FqLaPr7YuJx4SbNm2"
}

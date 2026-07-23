// Marks one of my own trophy_award rows as seen, dismissing the reveal
// ceremony for it permanently.
query "trophies/{id}/seen" verb=POST {
  api_group = "brackets"
  auth = "user"

  input {
    int id
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.get trophy_award {
      field_name = "id"
      field_value = $input.id
    } as $award

    precondition ($award != null && $award.recipient_user_id == $auth.id) {
      error_type = "accessdenied"
      error = "That's not your trophy."
    }

    db.edit trophy_award {
      field_name = "id"
      field_value = $input.id
      data = {seen: true}
    } as $updated
  }

  response = $updated
  guid = "3Dw6i9d2Y4Dq2Ggo6yxA6bJqCNc"
}

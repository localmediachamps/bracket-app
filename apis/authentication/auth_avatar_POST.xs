// Upload a profile avatar image and set it as the current user's avatar_url
// in one step (same storage.create_attachment mechanism as
// admin_tournament_upload_pdf_POST.xs). Returns the updated user record
// (password stripped), same shape as auth/me PATCH, so the caller can just
// swap it straight into the auth store.
query "auth/avatar" verb=POST {
  api_group = "Authentication"
  auth = "user"

  input {
    // The avatar image (multipart file field)
    file? avatar_file
  }

  stack {
    precondition ($input.avatar_file != null) {
      error_type = "inputerror"
      error = "Missing avatar_file."
    }

    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $me

    precondition ($me != null) {
      error_type = "notfound"
      error = "User not found."
    }

    // The vault path Xano generates already guarantees uniqueness per
    // upload - this filename is just for readability, not dedup.
    storage.create_attachment {
      value = $input.avatar_file
      access = "public"
      filename = "avatar-" ~ ($auth.id|to_text)
    } as $attachment

    var $avatar_url {
      value = "https://xhuf-7flt-jytp.n7d.xano.io" ~ $attachment.path
    }

    db.patch user {
      field_name = "id"
      field_value = $auth.id
      data = {
        avatar_url: $avatar_url
        updated_at: now
      }
    } as $updated_user

    var $user_out {
      value = $updated_user|unset:"password"
    }
  }

  response = $user_out
  guid = "Qh3nRtY8mZLpXwVcKdEo5FbT2sN"
}

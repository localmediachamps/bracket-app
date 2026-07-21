// Dedicated partial-field backfill for winner/loser_canonical_wrestler_id -
// separate from admin_wrestler_match_history_upsert_POST.xs (which
// overwrites every field via db.add_or_edit) so this can do a genuine
// partial db.edit without needing to resend all ~20 other columns for
// ~95k rows. Idempotent on source_match_id (looked up, then edited by its
// real id - db.edit's field_name/field_value only supports one lookup key
// per call the same way db.add_or_edit does, but does NOT overwrite fields
// absent from data, unlike add_or_edit).
query "admin/wrestler-match-history/canonical-backfill" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    object[1:1000] rows {
      schema {
        text source_match_id filters=trim
        int? winner_canonical_wrestler_id?
        int? loser_canonical_wrestler_id?
      }
    }
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    var $processed_count { value = 0 }
    var $errors { value = [] }

    foreach ($input.rows) {
      each as $r {
        try_catch {
          try {
            db.query wrestler_match_history {
              where = $db.wrestler_match_history.source_match_id == $r.source_match_id
              return = {type: "single"}
            } as $existing

            conditional {
              if ($existing != null) {
                db.edit wrestler_match_history {
                  field_name = "id"
                  field_value = $existing.id
                  data = {
                    winner_canonical_wrestler_id: $r.winner_canonical_wrestler_id
                    loser_canonical_wrestler_id : $r.loser_canonical_wrestler_id
                  }
                } as $updated

                math.add $processed_count { value = 1 }
              }
            }
          }
          catch {
            array.push $errors { value = {source_match_id: $r.source_match_id, message: $error.message} }
          }
        }
      }
    }
  }

  response = {
    received   : $input.rows|count
    processed  : $processed_count
    error_count: $errors|count
    errors     : $errors
  }
  guid = "TzX8kM4nRqDpBw3sYfLcGe7NvKt"
}

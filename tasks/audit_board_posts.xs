// Periodic AI sweep of message-board posts (every 10 min) - the "regular
// audit" moderation path, deliberately NOT run synchronously at post
// creation (would be one OpenAI call per post; batching many posts into one
// call here is far cheaper at real scale). The other, instant moderation
// path is any user reporting a post (apis/board/board_post_report_POST.xs),
// which hides it immediately without waiting for this sweep. Both paths
// converge on the same moderation_status + admin review queue.
task audit_board_posts {
  stack {
    db.query board_post {
      where = $db.board_post.ai_reviewed == false && $db.board_post.moderation_status == "visible"
      sort = {board_post.created_at: "asc"}
      return = {type: "list", paging: {page: 1, per_page: 25}}
    } as $pending

    var $checked_count {
      value = 0
    }

    var $flagged_count {
      value = 0
    }

    conditional {
      if (($pending.items|count) > 0) {
        var $batch {
          value = []
        }

        foreach ($pending.items) {
          each as $p {
            array.push $batch {
              value = {id: $p.id, body: $p.body}
            }
          }
        }

        try_catch {
          try {
            function.run moderate_board_posts_batch {
              input = {posts: $batch}
            } as $mod_result

            foreach ($mod_result.results) {
              each as $r {
                var $post_id {
                  value = $r|get:"id":null
                }

                var $flagged_raw {
                  value = $r|get:"flagged":null
                }

                // NOT `$flagged_raw == false` - null == false is a confirmed
                // XanoScript engine bug (see CLAUDE.md). Null-guard first.
                var $is_flagged {
                  value = false
                }

                conditional {
                  if ($flagged_raw != null && $flagged_raw == true) {
                    var.update $is_flagged {
                      value = true
                    }
                  }
                }

                var $reason {
                  value = $r|get:"reason":null
                }

                conditional {
                  if ($post_id != null) {
                    conditional {
                      if ($is_flagged) {
                        db.edit board_post {
                          field_name = "id"
                          field_value = $post_id
                          data = {
                            moderation_status: "flagged"
                            flag_reason      : $reason
                            flag_source       : "ai"
                            ai_reviewed       : true
                          }
                        } as $updated_flagged

                        math.add $flagged_count {
                          value = 1
                        }
                      }
                      else {
                        db.edit board_post {
                          field_name = "id"
                          field_value = $post_id
                          data = {ai_reviewed: true}
                        } as $updated_clean
                      }
                    }

                    math.add $checked_count {
                      value = 1
                    }
                  }
                }
              }
            }
          }

          catch {
            debug.log {
              value = {error: $error.message, batch_size: ($batch|count)}
            }
          }
        }
      }
    }

    debug.log {
      value = {checked: $checked_count, flagged: $flagged_count}
    }
  }

  schedule = [{starts_on: 2026-07-24 00:00:00+0000, freq: 600}]
  guid = "mGfoDBQvNU3_KVOxaSepVQ3NHY0"
}

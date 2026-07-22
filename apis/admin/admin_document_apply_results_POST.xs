// Applies a reviewed results_import extraction (see parse_results_pdf.xs) to
// the linked tournament's bracket_match rows. For each extracted result,
// resolves winner_name/loser_name to wrestler ids (normalized-name match
// within that weight class), then finds the pending bracket_match whose two
// CURRENT participants are exactly that pair and calls apply_match_result -
// same function the one-at-a-time admin UI uses, so advancement/consolation
// drops/bye-completion all work identically. Multiple passes are needed
// because entering an early round is what resolves later rounds'
// participants (and drops a loser into the consolation bracket) - each pass
// re-reads the bracket_match rows fresh and applies whatever is now
// resolvable, until a pass makes no further progress.
query "admin/documents/{id}/apply-results" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    // Uploaded document ID (doc_type must be results_import)
    int id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    db.get uploaded_document {
      field_name = "id"
      field_value = $input.id
    } as $document

    precondition ($document != null) {
      error_type = "notfound"
      error = "Document not found."
    }

    precondition ($document.doc_type == "results_import") {
      error_type = "inputerror"
      error = "This document is not a results import."
    }

    precondition ($document.processing_status == "needs_review" || $document.processing_status == "confirmed") {
      error_type = "inputerror"
      error = "Document is not in an applicable state (current: " ~ $document.processing_status ~ ")."
    }

    precondition ($document.tournament_id != null) {
      error_type = "inputerror"
      error = "Document is not linked to a tournament."
    }

    var $tournament_id {
      value = $document.tournament_id
    }

    var $weights {
      value = $document.extraction_result|get:"weights":[]
    }

    var $applied_count {
      value = 0
    }

    var $unresolved {
      value = []
    }

    var $weights_processed {
      value = 0
    }

    foreach ($weights) {
      each as $w {
        math.add $weights_processed {
          value = 1
        }

        db.query weight_class {
          where = $db.weight_class.tournament_id == $tournament_id && $db.weight_class.weight == $w.weight
          return = {type: "single"}
        } as $wc

        conditional {
          if ($wc == null) {
            array.push $unresolved {
              value = {weight: $w.weight, reason: "No matching weight class in this tournament."}
            }
          }
          else {
            db.query wrestler {
              where = $db.wrestler.weight_class_id == $wc.id
              return = {type: "list"}
            } as $wrestlers

            var $name_lookup {
              value = {}
            }

            foreach ($wrestlers) {
              each as $wr {
                var $wr_key {
                  value = $wr.name|to_lower|trim
                }

                var.update $name_lookup {
                  value = $name_lookup|set:$wr_key:$wr.id
                }
              }
            }

            var $match_list {
              value = $w|get:"matches":[]
            }

            var $match_count {
              value = $match_list|count
            }

            // applied[idx-as-text] = true once that extracted result has
            // been successfully matched + applied
            var $applied_flags {
              value = {}
            }

            var $pass_idx {
              value = 0
            }

            var $keep_going {
              value = true
            }

            while ($keep_going && $pass_idx < 8) {
              each {
                math.add $pass_idx {
                  value = 1
                }

                var $progress_this_pass {
                  value = false
                }

                db.query bracket_match {
                  where = $db.bracket_match.weight_class_id == $wc.id && $db.bracket_match.is_bye == false
                  return = {type: "list"}
                } as $current_matches

                for ($match_count) {
                  each as $midx {
                    var $mkey {
                      value = $midx|to_text
                    }

                    var $already_applied {
                      value = false
                    }

                    conditional {
                      if ($applied_flags|has:$mkey) {
                        var.update $already_applied {
                          value = $applied_flags|get:$mkey:false
                        }
                      }
                    }

                    conditional {
                      if ($already_applied == false) {
                        var $mres {
                          value = $match_list[$midx]
                        }

                        var $winner_key {
                          value = $mres.winner_name|to_lower|trim
                        }

                        var $loser_key {
                          value = $mres.loser_name|to_lower|trim
                        }

                        var $winner_id {
                          value = null
                        }

                        var $loser_id {
                          value = null
                        }

                        conditional {
                          if ($name_lookup|has:$winner_key) {
                            var.update $winner_id {
                              value = $name_lookup|get:$winner_key:null
                            }
                          }
                        }

                        conditional {
                          if ($name_lookup|has:$loser_key) {
                            var.update $loser_id {
                              value = $name_lookup|get:$loser_key:null
                            }
                          }
                        }

                        conditional {
                          if ($winner_id != null && $loser_id != null) {
                            // Find the pending match whose current two
                            // participants are exactly this pair
                            var $found_match {
                              value = null
                            }

                            foreach ($current_matches) {
                              each as $cm {
                                conditional {
                                  if ($found_match == null && $cm.match_status == "pending") {
                                    var $top_ok {
                                      value = ($cm.actual_top_wrestler_id == $winner_id && $cm.actual_bottom_wrestler_id == $loser_id) || ($cm.actual_top_wrestler_id == $loser_id && $cm.actual_bottom_wrestler_id == $winner_id)
                                    }

                                    conditional {
                                      if ($top_ok) {
                                        var.update $found_match {
                                          value = $cm
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }

                            conditional {
                              if ($found_match != null) {
                                // Another extraction entry applied earlier in
                                // THIS SAME PASS can bye-cascade-complete a
                                // different match that $current_matches (a
                                // snapshot from the top of the pass) still
                                // shows as pending - try_catch turns that
                                // stale-match race into "leave it for the
                                // next pass" instead of aborting the whole
                                // import.
                                var $apply_failed {
                                  value = false
                                }

                                try_catch {
                                  try {
                                    function.run apply_match_result {
                                      input = {
                                        bracket_match_id  : $found_match.id
                                        winner_wrestler_id: $winner_id
                                        victory_type      : $mres|get:"victory_type":null
                                        score             : $mres|get:"score":null
                                        actor_id          : $auth.id
                                      }
                                    } as $apply_result
                                  }

                                  catch {
                                    var.update $apply_failed {
                                      value = true
                                    }
                                  }
                                }

                                conditional {
                                  if ($apply_failed == false) {
                                    var.update $applied_flags {
                                      value = $applied_flags|set:$mkey:true
                                    }

                                    math.add $applied_count {
                                      value = 1
                                    }

                                    var.update $progress_this_pass {
                                      value = true
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }

                conditional {
                  if ($progress_this_pass == false) {
                    var.update $keep_going {
                      value = false
                    }
                  }
                }
              }
            }

            // Anything left unapplied after passes stop making progress
            for ($match_count) {
              each as $fidx {
                var $fkey {
                  value = $fidx|to_text
                }

                var $was_applied {
                  value = false
                }

                conditional {
                  if ($applied_flags|has:$fkey) {
                    var.update $was_applied {
                      value = $applied_flags|get:$fkey:false
                    }
                  }
                }

                conditional {
                  if ($was_applied == false) {
                    var $fres {
                      value = $match_list[$fidx]
                    }

                    array.push $unresolved {
                      value = {
                        weight     : $w.weight
                        winner_name: $fres.winner_name
                        loser_name : $fres.loser_name
                        reason     : "Could not match to a pending bracket match (wrestler name not found, or participants not yet resolved)."
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    db.edit uploaded_document {
      field_name = "id"
      field_value = $input.id
      data = {processing_status: "confirmed", tournament_id: $tournament_id}
    } as $document_confirmed

    function.run audit {
      input = {
        actor_id   : $auth.id
        entity_type: "tournament"
        entity_id  : $tournament_id
        action     : "results_import_applied"
        metadata   : {document_id: $input.id, applied: $applied_count, unresolved: ($unresolved|count)}
      }
    } as $audit_row
  }

  response = {
    weights_processed: $weights_processed
    applied          : $applied_count
    unresolved       : $unresolved
  }
  guid = "QvaD4IG7Cp7aY9ZxdhP5dzvNukY"
}

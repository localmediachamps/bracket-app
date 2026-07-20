// One-time maintenance utility: deletes every tournament except keep_tournament_id,
// along with all rows in dependent tables that reference the removed tournaments
// (weight_class, bracket_match, wrestler, user_bracket, user_pick, pickem_entry,
// pickem_pick, uploaded_document, ingestion_conflict, match_result_history,
// external_result_candidate, results_source_config, fantasy_group, group_membership,
// audit_log). Not wired to any API endpoint — invoke directly via
// `xano function run reset_test_tournaments -d keep_tournament_id:=<id> -d dry_run:=true`.
// Defaults to dry_run=true: reports counts without deleting anything.
function reset_test_tournaments {
  input {
    // Tournament id to keep — every other tournament (and its dependent rows) is removed
    int keep_tournament_id

    // When true (default), only counts what would be deleted — no writes happen
    bool dry_run?=true
  }

  stack {
    db.query tournament {
      where = $db.tournament.id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 500}}
    } as $doomed_tournaments

    var $doomed_ids {
      value = []
    }

    foreach ($doomed_tournaments) {
      each as $t {
        array.push $doomed_ids {
          value = $t.id
        }
      }
    }

    // ------------------------------------------------------------------
    // Tables with a direct tournament_id column
    // ------------------------------------------------------------------
    db.query weight_class {
      where = $db.weight_class.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_weight_class

    foreach ($rows_weight_class) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del weight_class {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query bracket_match {
      where = $db.bracket_match.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_bracket_match

    foreach ($rows_bracket_match) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del bracket_match {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query wrestler {
      where = $db.wrestler.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_wrestler

    foreach ($rows_wrestler) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del wrestler {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query user_bracket {
      where = $db.user_bracket.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_user_bracket

    foreach ($rows_user_bracket) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del user_bracket {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query user_pick {
      where = $db.user_pick.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_user_pick

    foreach ($rows_user_pick) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del user_pick {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query pickem_entry {
      where = $db.pickem_entry.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_pickem_entry

    foreach ($rows_pickem_entry) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del pickem_entry {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query pickem_pick {
      where = $db.pickem_pick.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_pickem_pick

    foreach ($rows_pickem_pick) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del pickem_pick {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query uploaded_document {
      where = $db.uploaded_document.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_uploaded_document

    foreach ($rows_uploaded_document) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del uploaded_document {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query ingestion_conflict {
      where = $db.ingestion_conflict.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_ingestion_conflict

    foreach ($rows_ingestion_conflict) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del ingestion_conflict {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query match_result_history {
      where = $db.match_result_history.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_match_result_history

    foreach ($rows_match_result_history) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del match_result_history {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query external_result_candidate {
      where = $db.external_result_candidate.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_external_result_candidate

    foreach ($rows_external_result_candidate) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del external_result_candidate {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    db.query results_source_config {
      where = $db.results_source_config.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_results_source_config

    foreach ($rows_results_source_config) {
      each as $r {
        conditional {
          if (!$input.dry_run) {
            db.del results_source_config {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      }
    }

    // ------------------------------------------------------------------
    // fantasy_group + its group_membership rows (membership has no
    // tournament_id of its own, only group_id)
    // ------------------------------------------------------------------
    db.query fantasy_group {
      where = $db.fantasy_group.tournament_id != $input.keep_tournament_id
      return = {type: "list", paging: {page: 1, per_page: 5000}}
    } as $rows_fantasy_group

    var $membership_count {
      value = 0
    }

    foreach ($rows_fantasy_group) {
      each as $g {
        db.query group_membership {
          where = $db.group_membership.group_id == $g.id
          return = {type: "list", paging: {page: 1, per_page: 5000}}
        } as $rows_membership

        foreach ($rows_membership) {
          each as $m {
            conditional {
              if (!$input.dry_run) {
                db.del group_membership {
                  field_name = "id"
                  field_value = $m.id
                }
              }
            }
          }
        }

        math.add $membership_count {
          value = ($rows_membership|count)
        }

        conditional {
          if (!$input.dry_run) {
            db.del fantasy_group {
              field_name = "id"
              field_value = $g.id
            }
          }
        }
      }
    }

    // ------------------------------------------------------------------
    // audit_log rows for the removed tournaments (entity_type is polymorphic —
    // only cleaning up rows directly logged against the tournament entity)
    // ------------------------------------------------------------------
    var $audit_count {
      value = 0
    }

    foreach ($doomed_ids) {
      each as $tid {
        db.query audit_log {
          where = $db.audit_log.entity_type == "tournament" && $db.audit_log.entity_id == $tid
          return = {type: "list", paging: {page: 1, per_page: 5000}}
        } as $rows_audit

        foreach ($rows_audit) {
          each as $a {
            conditional {
              if (!$input.dry_run) {
                db.del audit_log {
                  field_name = "id"
                  field_value = $a.id
                }
              }
            }
          }
        }

        math.add $audit_count {
          value = ($rows_audit|count)
        }
      }
    }

    // ------------------------------------------------------------------
    // Finally, the tournaments themselves
    // ------------------------------------------------------------------
    foreach ($doomed_tournaments) {
      each as $t {
        conditional {
          if (!$input.dry_run) {
            db.del tournament {
              field_name = "id"
              field_value = $t.id
            }
          }
        }
      }
    }

    var $counts {
      value = {weight_class: ($rows_weight_class|count), bracket_match: ($rows_bracket_match|count), wrestler: ($rows_wrestler|count), user_bracket: ($rows_user_bracket|count), user_pick: ($rows_user_pick|count), pickem_entry: ($rows_pickem_entry|count), pickem_pick: ($rows_pickem_pick|count), uploaded_document: ($rows_uploaded_document|count), ingestion_conflict: ($rows_ingestion_conflict|count), match_result_history: ($rows_match_result_history|count), external_result_candidate: ($rows_external_result_candidate|count), results_source_config: ($rows_results_source_config|count), fantasy_group: ($rows_fantasy_group|count), group_membership: $membership_count, audit_log: $audit_count, tournament: ($doomed_tournaments|count)}
    }
  }

  response = {
    dry_run: $input.dry_run
    keep_tournament_id: $input.keep_tournament_id
    deleted_tournament_ids: $doomed_ids
    counts: $counts
  }
}

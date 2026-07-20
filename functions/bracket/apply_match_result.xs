// Applies, corrects, or clears a match result (ARCHITECTURE.md section 2).
//   - Enter: match pending -> sets winner/loser, advances both.
//   - Correct: match already complete/corrected -> requires change_reason,
//     refuses when a downstream destination is already complete (409).
//   - Clear (clear=true): requires change_reason, unwinds downstream
//     participant slots only where those matches are still pending.
// All paths: optimistic concurrency via expected_version, match_result_history
// row, audit_log row, tournament.needs_rescore = true.
// Enter, correct, or clear a bracket match result with advancement, history and audit
function apply_match_result {
  input {
    // Match to apply the result to
    int bracket_match_id
  
    // Winning wrestler (must be a participant unless match_status=cancelled or clear=true)
    int? winner_wrestler_id?
  
    // decision | major | tech_fall | fall | medical_forfeit | injury_default | disqualification | forfeit
    text? victory_type? filters=trim
  
    // Score text, e.g. '7-2'
    text? score? filters=trim
  
    // Resulting match status: complete | corrected | cancelled
    text? match_status?=complete filters=trim
  
    // Result notes stored on the match
    text? notes? filters=trim
  
    // Required for corrections and clears
    text? change_reason? filters=trim
  
    // Optimistic concurrency: must match current match version when provided
    int? expected_version?
  
    // User id performing the change (audit)
    int? actor_id?
  
    // When true, clears the result instead of entering one
    bool? clear?
  }

  stack {
    precondition (($input.match_status == "complete") || ($input.match_status == "corrected") || ($input.match_status == "cancelled")) {
      error_type = "inputerror"
      error = "match_status must be complete, corrected or cancelled."
    }
  
    db.get bracket_match {
      field_name = "id"
      field_value = $input.bracket_match_id
    } as $match
  
    precondition ($match != null) {
      error_type = "notfound"
      error = "Match not found."
    }
  
    // Optimistic concurrency
    precondition (($input.expected_version == null) || ($input.expected_version == $match.version)) {
      error = "409:VERSION_CONFLICT expected_version=" ~ ($input.expected_version|first_notnull:-1) ~ " current_version=" ~ $match.version
    }
  
    // Downstream-complete guard data (winner + loser destinations)
    var $winner_dest_match {
      value = null
    }
  
    conditional {
      if ($match.winner_advances_to_match_id != null) {
        db.get bracket_match {
          field_name = "id"
          field_value = $match.winner_advances_to_match_id
        } as $wdm
      
        var.update $winner_dest_match {
          value = $wdm
        }
      }
    }
  
    var $loser_dest_match {
      value = null
    }
  
    conditional {
      if ($match.loser_drops_to_match_id != null) {
        db.get bracket_match {
          field_name = "id"
          field_value = $match.loser_drops_to_match_id
        } as $ldm
      
        var.update $loser_dest_match {
          value = $ldm
        }
      }
    }
  
    // Snapshot for history/audit
    var $previous_value {
      value = {
        winner      : $match.actual_winner_wrestler_id
        loser       : $match.actual_loser_wrestler_id
        victory_type: $match.victory_type
        score       : $match.actual_score
        status      : $match.match_status
        version     : $match.version
      }
    }
  
    var $new_version {
      value = $match.version + 1
    }
  
    var $result_match {
      value = null
    }
  
    var $advanced_to {
      value = null
    }
  
    var $dropped_to {
      value = null
    }
  
    conditional {
      if ($input.clear) {
        // --------------------------------------------------------------
        // CLEAR PATH
        // --------------------------------------------------------------
        precondition (($input.change_reason != null) && (($input.change_reason|strlen) > 0)) {
          error_type = "inputerror"
          error = "change_reason is required to clear a result."
        }
      
        precondition (($match.match_status == "complete") || ($match.match_status == "corrected")) {
          error_type = "inputerror"
          error = "Match has no result to clear."
        }
      
        precondition (($winner_dest_match == null) || (($winner_dest_match.match_status != "complete") && ($winner_dest_match.match_status != "corrected"))) {
          error = "409:DOWNSTREAM_COMPLETE downstream_match_id=" ~ $winner_dest_match.id ~ " - correct the downstream match first."
        }
      
        precondition (($loser_dest_match == null) || (($loser_dest_match.match_status != "complete") && ($loser_dest_match.match_status != "corrected"))) {
          error = "409:DOWNSTREAM_COMPLETE downstream_match_id=" ~ $loser_dest_match.id ~ " - correct the downstream match first."
        }
      
        // 1) Match row + history first
        db.edit bracket_match {
          field_name = "id"
          field_value = $match.id
          data = {
            actual_winner_wrestler_id: null
            actual_loser_wrestler_id : null
            victory_type             : null
            actual_score             : null
            result_notes             : null
            match_status             : "pending"
            completed_at             : null
            version                  : $new_version
            updated_at               : "now"
          }
        } as $cleared_match
      
        var.update $result_match {
          value = $cleared_match
        }
      
        db.add match_result_history {
          data = {
            bracket_match_id  : $match.id
            tournament_id     : $match.tournament_id
            version           : $new_version
            winner_wrestler_id: null
            loser_wrestler_id : null
            score             : null
            victory_type      : null
            match_status      : "pending"
            change_type       : "cleared"
            change_reason     : $input.change_reason
            changed_by        : $input.actor_id
          }
        } as $history_row
      
        // 2) Unwind destination participant slots (pending destinations only)
        conditional {
          if ($winner_dest_match != null) {
            conditional {
              if ($winner_dest_match.match_status == "pending") {
                var $clear_w_field {
                  value = "actual_" ~ $match.winner_slot_in_next ~ "_wrestler_id"
                }
              
                var $clear_w_payload {
                  value = {}|set:$clear_w_field:null
                }
              
                db.patch bracket_match {
                  field_name = "id"
                  field_value = $winner_dest_match.id
                  data = $clear_w_payload
                } as $unwind_w
              }
            }
          }
        }
      
        conditional {
          if ($loser_dest_match != null) {
            conditional {
              if ($loser_dest_match.match_status == "pending") {
                var $clear_l_field {
                  value = "actual_" ~ $match.loser_slot_in_next ~ "_wrestler_id"
                }
              
                var $clear_l_payload {
                  value = {}|set:$clear_l_field:null
                }
              
                db.patch bracket_match {
                  field_name = "id"
                  field_value = $loser_dest_match.id
                  data = $clear_l_payload
                } as $unwind_l
              }
            }
          }
        }
      
        db.add audit_log {
          data = {
            actor_id      : $input.actor_id
            entity_type   : "bracket_match"
            entity_id     : $match.id
            action        : "result_cleared"
            previous_value: $previous_value
            new_value     : {
            winner : null
            loser  : null
            status : "pending"
            version: $new_version
          }
            metadata      : {change_reason: $input.change_reason}
          }
        } as $audit_row
      }
    
      else {
        // --------------------------------------------------------------
        // ENTER / CORRECT PATH
        // --------------------------------------------------------------
        precondition ($match.is_bye == false) {
          error_type = "inputerror"
          error = "Bye matches are completed automatically and cannot take a result."
        }
      
        var $top_participant {
          value = $match.actual_top_wrestler_id
        }
      
        var $bottom_participant {
          value = $match.actual_bottom_wrestler_id
        }
      
        // Winner must be one of the two participants (unless cancelled)
        conditional {
          if ($input.match_status != "cancelled") {
            precondition (($input.winner_wrestler_id != null) && (($input.winner_wrestler_id == $top_participant) || ($input.winner_wrestler_id == $bottom_participant))) {
              error_type = "inputerror"
              error = "winner_wrestler_id must be a participant of this match."
            }
          }
        }
      
        var $loser_wrestler_id {
          value = null
        }
      
        conditional {
          if ($input.match_status != "cancelled") {
            conditional {
              if (($input.winner_wrestler_id == $top_participant)) {
                var.update $loser_wrestler_id {
                  value = $bottom_participant
                }
              }
            
              else {
                var.update $loser_wrestler_id {
                  value = $top_participant
                }
              }
            }
          }
        }
      
        var $is_correction {
          value = ($match.match_status == "complete") || ($match.match_status == "corrected")
        }
      
        conditional {
          if ($is_correction) {
            precondition (($input.change_reason != null) && (($input.change_reason|strlen) > 0)) {
              error_type = "inputerror"
              error = "change_reason is required to correct a recorded result."
            }
          }
        }
      
        // Downstream-complete guard: never silently overwrite a finished match
        precondition (($winner_dest_match == null) || (($winner_dest_match.match_status != "complete") && ($winner_dest_match.match_status != "corrected"))) {
          error = "409:DOWNSTREAM_COMPLETE downstream_match_id=" ~ $winner_dest_match.id ~ " - correct the downstream match first."
        }
      
        precondition (($loser_dest_match == null) || (($loser_dest_match.match_status != "complete") && ($loser_dest_match.match_status != "corrected"))) {
          error = "409:DOWNSTREAM_COMPLETE downstream_match_id=" ~ $loser_dest_match.id ~ " - correct the downstream match first."
        }
      
        // 1) Match row + history first
        var $change_type {
          value = null
        }
      
        conditional {
          if ($is_correction) {
            var.update $change_type {
              value = "corrected"
            }
          }
        
          else {
            var.update $change_type {
              value = "entered"
            }
          }
        }
      
        var $audit_action {
          value = null
        }
      
        conditional {
          if ($is_correction) {
            var.update $audit_action {
              value = "result_corrected"
            }
          }
        
          else {
            var.update $audit_action {
              value = "result_entered"
            }
          }
        }
      
        db.edit bracket_match {
          field_name = "id"
          field_value = $match.id
          data = {
            actual_winner_wrestler_id: $input.winner_wrestler_id
            actual_loser_wrestler_id : $loser_wrestler_id
            victory_type             : $input.victory_type
            actual_score             : $input.score
            result_notes             : $input.notes
            match_status             : $input.match_status
            completed_at             : "now"
            version                  : $new_version
            updated_at               : "now"
          }
        } as $updated_match
      
        var.update $result_match {
          value = $updated_match
        }
      
        db.add match_result_history {
          data = {
            bracket_match_id  : $match.id
            tournament_id     : $match.tournament_id
            version           : $new_version
            winner_wrestler_id: $input.winner_wrestler_id
            loser_wrestler_id : $loser_wrestler_id
            score             : $input.score
            victory_type      : $input.victory_type
            match_status      : $input.match_status
            change_type       : $change_type
            change_reason     : $input.change_reason
            changed_by        : $input.actor_id
          }
        } as $history_row
      
        // 2) Advance winner / drop loser (skipped for cancelled matches)
        var $bye_queue {
          value = []
        }
      
        conditional {
          if ($input.match_status != "cancelled") {
            conditional {
              if (($match.winner_advances_to_match_id != null) && ($input.winner_wrestler_id != null)) {
                var $adv_w_field {
                  value = "actual_" ~ $match.winner_slot_in_next ~ "_wrestler_id"
                }
              
                var $adv_w_payload {
                  value = {}
                    |set:$adv_w_field:$input.winner_wrestler_id
                }
              
                db.patch bracket_match {
                  field_name = "id"
                  field_value = $match.winner_advances_to_match_id
                  data = $adv_w_payload
                } as $adv_w
              
                var.update $advanced_to {
                  value = $match.winner_advances_to_match_id
                }
              
                array.push $bye_queue {
                  value = $match.winner_advances_to_match_id
                }
              }
            }
          
            conditional {
              if (($match.loser_drops_to_match_id != null) && ($loser_wrestler_id != null)) {
                var $adv_l_field {
                  value = "actual_" ~ $match.loser_slot_in_next ~ "_wrestler_id"
                }
              
                var $adv_l_payload {
                  value = {}
                    |set:$adv_l_field:$loser_wrestler_id
                }
              
                db.patch bracket_match {
                  field_name = "id"
                  field_value = $match.loser_drops_to_match_id
                  data = $adv_l_payload
                } as $adv_l
              
                var.update $dropped_to {
                  value = $match.loser_drops_to_match_id
                }
              
                array.push $bye_queue {
                  value = $match.loser_drops_to_match_id
                }
              }
            }
          }
        }
      
        // 3) Auto-complete single-source destinations as byes (bounded)
        var $bye_iterations {
          value = 0
        }
      
        while ((($bye_queue|count) > 0) && ($bye_iterations < 10)) {
          each {
            var.update $bye_iterations {
              value = $bye_iterations + 1
            }
          
            array.shift $bye_queue as $check_match_id
            db.get bracket_match {
              field_name = "id"
              field_value = $check_match_id
            } as $dest_match
          
            conditional {
              if (($dest_match != null) && ($dest_match.match_status == "pending")) {
                var $dest_top {
                  value = $dest_match.actual_top_wrestler_id
                }
              
                var $dest_bottom {
                  value = $dest_match.actual_bottom_wrestler_id
                }
              
                conditional {
                  if (($dest_top != null) && ($dest_bottom != null)) {
                    var $dest_empty_source {
                      value = null
                    }
                  
                    conditional {
                      if (($dest_top == null)) {
                        var.update $dest_empty_source {
                          value = $dest_match.top_source_type
                        }
                      }
                    
                      else {
                        var.update $dest_empty_source {
                          value = $dest_match.bottom_source_type
                        }
                      }
                    }
                  
                    // Single participant whose other slot has no source at all:
                    // auto-complete as a bye and propagate
                    conditional {
                      if ($dest_empty_source == null) {
                        var $dest_bye_winner {
                          value = null
                        }
                      
                        conditional {
                          if (($dest_top != null)) {
                            var.update $dest_bye_winner {
                              value = $dest_top
                            }
                          }
                        
                          else {
                            var.update $dest_bye_winner {
                              value = $dest_bottom
                            }
                          }
                        }
                      
                        db.edit bracket_match {
                          field_name = "id"
                          field_value = $dest_match.id
                          data = {
                            is_bye                   : true
                            match_status             : "complete"
                            actual_winner_wrestler_id: $dest_bye_winner
                            completed_at             : "now"
                            version                  : $dest_match.version + 1
                            updated_at               : "now"
                          }
                        } as $dest_bye_upd
                      
                        conditional {
                          if (($dest_match.winner_advances_to_match_id != null) && ($dest_bye_winner != null)) {
                            var $dest_adv_field {
                              value = "actual_" ~ $dest_match.winner_slot_in_next ~ "_wrestler_id"
                            }
                          
                            var $dest_adv_payload {
                              value = {}
                                |set:$dest_adv_field:$dest_bye_winner
                            }
                          
                            db.patch bracket_match {
                              field_name = "id"
                              field_value = $dest_match.winner_advances_to_match_id
                              data = $dest_adv_payload
                            } as $dest_adv
                          
                            array.push $bye_queue {
                              value = $dest_match.winner_advances_to_match_id
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
      
        db.add audit_log {
          data = {
            actor_id      : $input.actor_id
            entity_type   : "bracket_match"
            entity_id     : $match.id
            action        : $audit_action
            previous_value: $previous_value
            new_value     : {
            winner      : $input.winner_wrestler_id
            loser       : $loser_wrestler_id
            victory_type: $input.victory_type
            score       : $input.score
            status      : $input.match_status
            version     : $new_version
          }
            metadata      : {change_reason: $input.change_reason}
          }
        } as $audit_row
      }
    }
  
    // Flag the tournament for rescoring
    db.edit tournament {
      field_name = "id"
      field_value = $match.tournament_id
      data = {needs_rescore: true}
    } as $tournament_upd
  
    var $result {
      value = {
        match      : $result_match
        advanced_to: $advanced_to
        dropped_to : $dropped_to
        rescoring  : true
      }
    }
  }

  response = $result
}
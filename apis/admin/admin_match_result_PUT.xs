// Enter or correct a match result (ARCHITECTURE.md sections 2 and 6:
// PUT /admin/matches/{id}/result).
// Delegates to apply_match_result (advancement, history, version checks, audit).
// Its 409 VERSION_CONFLICT / DOWNSTREAM_COMPLETE precondition errors are NOT caught
// here — they propagate to the caller. Afterwards the whole tournament is rescored
// inline (acceptable at MVP scale).
query "admin/matches/{id}/result" verb=PUT {
  api_group = "admin"
  auth = "user"

  input {
    // Bracket match ID
    int id
  
    // Winning wrestler ID
    int winner_wrestler_id
  
    // decision | major | tech_fall | fall | medical_forfeit | injury_default | disqualification | forfeit
    text? victory_type? filters=trim|lower
  
    // Match score, e.g. "7-2"
    text? score? filters=trim
  
    // Result notes
    text? notes? filters=trim
  
    // Optimistic concurrency: expected current bracket_match.version
    int? expected_version?
  
    // Required by apply_match_result when correcting an existing result
    text? change_reason? filters=trim
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get bracket_match {
      field_name = "id"
      field_value = $input.id
    } as $match
  
    precondition ($match != null) {
      error_type = "notfound"
      error = "Bracket match not found."
    }
  
    var $victory_types {
      value = [
        "decision"
        "major"
        "tech_fall"
        "fall"
        "medical_forfeit"
        "injury_default"
        "disqualification"
        "forfeit"
      ]
    }
  
    precondition ($input.victory_type == null || $victory_types|some:$$ == $input.victory_type) {
      error_type = "inputerror"
      error = "victory_type must be one of: " ~ ($victory_types|join:", ") ~ "."
    }
  
    // Conflict preconditions (version mismatch, downstream complete) bubble up as 409s
    function.run apply_match_result {
      input = {
        bracket_match_id  : $input.id
        actor_id          : $auth.id
        winner_wrestler_id: $input.winner_wrestler_id
        victory_type      : $input.victory_type
        score             : $input.score
        notes             : $input.notes
        change_reason     : $input.change_reason
        expected_version  : $input.expected_version
      }
    } as $match_result
  
    // Inline rescore of the whole tournament (MVP scale)
    function.run rescore_tournament {
      input = {tournament_id: $match.tournament_id}
    } as $rescore_summary
  }

  response = {match: $match_result, rescored: true}
}
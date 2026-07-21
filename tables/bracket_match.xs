table bracket_match {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int tournament_id
    int weight_class_id
  
    // pigtail | champ_r1..champ_r6 | champ_finals | cons_r1..cons_r8 | place_3 | place_5 | place_7
    text round_code
  
    // ordering within bracket_section (championship: 1..k)
    int round_number?
  
    // "First Round" | "Quarterfinals" | "Semifinals" | "Championship" | "Blood Round" | "3rd Place" ...
    text round_label?
  
    // 1-based position within the round
    int match_number
  
    // global tiebreak for layout
    int display_order?
  
    // championship | consolation | placement
    text bracket_section
  
    // slot sources: seed | match_winner | match_loser
    text top_source_type?
  
    int top_source_seed?
    int top_source_match_id?
    text bottom_source_type?
    int bottom_source_seed?
    int bottom_source_match_id?
  
    // the two wrestlers in this match (populated after bracket is initialized)
    int actual_top_wrestler_id?
  
    int actual_bottom_wrestler_id?
  
    // FK to bracket_match.id — where winner routes next (null = champion)
    int winner_advances_to_match_id?
  
    // which slot (top|bottom) in the next match the winner fills
    text winner_slot_in_next?
  
    // FK to bracket_match.id — where loser routes next (null = eliminated)
    int loser_drops_to_match_id?
  
    // which slot (top|bottom) in the next match the loser fills
    text loser_slot_in_next?
  
    // set by admin after match is played
    int actual_winner_wrestler_id?
  
    int actual_loser_wrestler_id?
  
    // decision | major | tech_fall | fall | medical_forfeit | injury_default | disqualification | forfeit
    text victory_type?
  
    text actual_score?
    text result_notes?
  
    // pending | in_progress | complete | corrected | cancelled
    text match_status?=pending
  
    // optimistic concurrency on result entry
    int version?=1
  
    timestamp completed_at?
    timestamp updated_at?
  
    // single-participant match (auto-advances)
    bool is_bye?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "weight_class_id", op: "asc"}]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "round_code", op: "asc"}]}
    {
      type : "btree|unique"
      field: [
        {name: "weight_class_id", op: "asc"}
        {name: "round_code", op: "asc"}
        {name: "match_number", op: "asc"}
      ]
    }
  ]
  guid = "MoV_cZhzl6QFRKbA2gNyOp9SaDs"
}
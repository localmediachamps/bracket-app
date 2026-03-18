table bracket_match {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int tournament_id
    int weight_class_id
  
    // round_code: pigtail | champ_r1 | champ_qf | champ_sf | champ_finals | champ_3rd
    //             cons_r1 | cons_r2 | cons_r3 | cons_r4 | cons_sf | cons_finals
    text round_code
  
    // position within that round (1-based)
    int match_number
  
    // championship | consolation
    text bracket_side
  
    // FK to bracket_match.id — where winner routes next (null = champion)
    int winner_advances_to_match_id?
  
    // FK to bracket_match.id — where loser routes next (null = eliminated)
    int loser_drops_to_match_id?
  
    // which slot (top|bottom) in the next match the winner/loser fills
    text winner_slot_in_next?
  
    text loser_slot_in_next?
  
    // the two wrestlers in this match (populated after bracket is initialized)
    int actual_top_wrestler_id?
  
    int actual_bottom_wrestler_id?
  
    // set by admin after match is played
    int actual_winner_wrestler_id?
  
    text actual_winner_decision?
    text actual_score?
  
    // pending | complete
    text match_status?=pending
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "weight_class_id", op: "asc"}]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "round_code", op: "asc"}]}
    {type: "btree", field: [{name: "match_number", op: "asc"}]}
  ]
}
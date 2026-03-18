// Generates all bracket_match rows for one weight class with full routing graph.
// NCAA DI Wrestling: 33 wrestlers per weight (seeds 1-33).
// Structure:
//   Pigtail:      1 match  (seed 32 vs 33) — loser eliminated, no consolation
//   Champ R1:    16 matches
//   Champ QF:     8 matches
//   Champ SF:     4 matches
//   Champ Finals: 1 match  (1st/2nd place)
//   Champ 3rd:    1 match  (3rd/4th place)
//   Cons R1:      8 matches (Champ R1 losers)
//   Cons R2:      8 matches (Cons R1 winners + Champ QF losers)
//   Cons R3:      4 matches (Cons R2 winners)
//   Cons R4:      4 matches (Cons R3 winners + Champ SF losers)
//   Cons SF:      2 matches (Cons R4 winners)
//   Cons Finals:  2 matches (5th/6th and 7th/8th place)
// Total: 59 matches per weight x 10 weights = 590 matches per tournament
function initialize_weight_bracket {
  input {
    int weight_class_id
    int tournament_id
  }

  stack {
    // Load the 33 wrestlers sorted by seed
    db.query wrestler {
      where = {} == true
      return = {type: "list"}
      output = ["id", "seed"]
    } as $wrestlers
  
    precondition (($wrestlers|count) != 33) {
      error_type = "inputerror"
      error = "Weight class must have exactly 33 wrestlers before initializing bracket."
    }
  
    // Build a seed->wrestler_id lookup map
    var $seed_map {
      value = {}
    }
  
    foreach ($wrestlers) {
      each as $w {
        var.update $seed_map {
          value = $seed_map|set:$w.seed:$w.id
        }
      }
    }
  
    // -----------------------------------------------------------------------
    // STEP 1: Insert all matches without routing FKs first
    // -----------------------------------------------------------------------
  
    // --- PIGTAIL (1 match) ---
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "pigtail"
        match_number             : 1
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[32]
        actual_bottom_wrestler_id: $seed_map[33]
        match_status             : "pending"
      }
    } as $pigtail_1
  
    // --- CHAMP R1 (16 matches) ---
    // Seed 1 vs pigtail winner (bottom slot null until pigtail resolves)
    db.add bracket_match {
      data = {
        tournament_id         : $input.tournament_id
        weight_class_id       : $input.weight_class_id
        round_code            : "champ_r1"
        match_number          : 1
        bracket_side          : "championship"
        actual_top_wrestler_id: $seed_map[1]
        match_status          : "pending"
      }
    } as $cr1_1
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 2
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[16]
        actual_bottom_wrestler_id: $seed_map[17]
        match_status             : "pending"
      }
    } as $cr1_2
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 3
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[8]
        actual_bottom_wrestler_id: $seed_map[25]
        match_status             : "pending"
      }
    } as $cr1_3
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 4
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[9]
        actual_bottom_wrestler_id: $seed_map[24]
        match_status             : "pending"
      }
    } as $cr1_4
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 5
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[5]
        actual_bottom_wrestler_id: $seed_map[28]
        match_status             : "pending"
      }
    } as $cr1_5
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 6
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[12]
        actual_bottom_wrestler_id: $seed_map[21]
        match_status             : "pending"
      }
    } as $cr1_6
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 7
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[4]
        actual_bottom_wrestler_id: $seed_map[29]
        match_status             : "pending"
      }
    } as $cr1_7
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 8
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[13]
        actual_bottom_wrestler_id: $seed_map[20]
        match_status             : "pending"
      }
    } as $cr1_8
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 9
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[2]
        actual_bottom_wrestler_id: $seed_map[31]
        match_status             : "pending"
      }
    } as $cr1_9
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 10
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[15]
        actual_bottom_wrestler_id: $seed_map[18]
        match_status             : "pending"
      }
    } as $cr1_10
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 11
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[7]
        actual_bottom_wrestler_id: $seed_map[26]
        match_status             : "pending"
      }
    } as $cr1_11
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 12
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[10]
        actual_bottom_wrestler_id: $seed_map[23]
        match_status             : "pending"
      }
    } as $cr1_12
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 13
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[3]
        actual_bottom_wrestler_id: $seed_map[30]
        match_status             : "pending"
      }
    } as $cr1_13
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 14
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[14]
        actual_bottom_wrestler_id: $seed_map[19]
        match_status             : "pending"
      }
    } as $cr1_14
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 15
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[6]
        actual_bottom_wrestler_id: $seed_map[27]
        match_status             : "pending"
      }
    } as $cr1_15
  
    db.add bracket_match {
      data = {
        tournament_id            : $input.tournament_id
        weight_class_id          : $input.weight_class_id
        round_code               : "champ_r1"
        match_number             : 16
        bracket_side             : "championship"
        actual_top_wrestler_id   : $seed_map[11]
        actual_bottom_wrestler_id: $seed_map[22]
        match_status             : "pending"
      }
    } as $cr1_16
  
    // --- CHAMP QF (8 matches) ---
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_qf"
        match_number   : 1
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $cqf_1
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_qf"
        match_number   : 2
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $cqf_2
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_qf"
        match_number   : 3
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $cqf_3
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_qf"
        match_number   : 4
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $cqf_4
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_qf"
        match_number   : 5
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $cqf_5
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_qf"
        match_number   : 6
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $cqf_6
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_qf"
        match_number   : 7
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $cqf_7
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_qf"
        match_number   : 8
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $cqf_8
  
    // --- CHAMP SF (4 matches) ---
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_sf"
        match_number   : 1
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $csf_1
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_sf"
        match_number   : 2
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $csf_2
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_sf"
        match_number   : 3
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $csf_3
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_sf"
        match_number   : 4
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $csf_4
  
    // --- CHAMP FINALS (1 match) ---
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_finals"
        match_number   : 1
        bracket_side   : "championship"
        match_status   : "pending"
      }
    } as $cfinals
  
    // --- CHAMP 3RD PLACE (1 match) ---
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "champ_3rd"
        match_number   : 1
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $c3rd
  
    // --- CONS R1 (8 matches - Champ R1 losers) ---
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r1"
        match_number   : 1
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr1_1
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r1"
        match_number   : 2
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr1_2
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r1"
        match_number   : 3
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr1_3
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r1"
        match_number   : 4
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr1_4
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r1"
        match_number   : 5
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr1_5
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r1"
        match_number   : 6
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr1_6
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r1"
        match_number   : 7
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr1_7
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r1"
        match_number   : 8
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr1_8
  
    // --- CONS R2 (8 matches - Cons R1 winners + Champ QF losers) ---
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r2"
        match_number   : 1
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr2_1
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r2"
        match_number   : 2
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr2_2
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r2"
        match_number   : 3
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr2_3
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r2"
        match_number   : 4
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr2_4
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r2"
        match_number   : 5
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr2_5
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r2"
        match_number   : 6
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr2_6
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r2"
        match_number   : 7
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr2_7
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r2"
        match_number   : 8
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr2_8
  
    // --- CONS R3 (4 matches - Cons R2 winners) ---
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r3"
        match_number   : 1
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr3_1
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r3"
        match_number   : 2
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr3_2
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r3"
        match_number   : 3
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr3_3
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r3"
        match_number   : 4
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr3_4
  
    // --- CONS R4 (4 matches - Cons R3 winners + Champ SF losers) ---
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r4"
        match_number   : 1
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr4_1
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r4"
        match_number   : 2
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr4_2
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r4"
        match_number   : 3
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr4_3
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_r4"
        match_number   : 4
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kr4_4
  
    // --- CONS SF (2 matches) ---
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_sf"
        match_number   : 1
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $ksf_1
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_sf"
        match_number   : 2
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $ksf_2
  
    // --- CONS FINALS (2 matches - 5th/6th and 7th/8th place) ---
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_finals"
        match_number   : 1
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kfinals_1
  
    db.add bracket_match {
      data = {
        tournament_id  : $input.tournament_id
        weight_class_id: $input.weight_class_id
        round_code     : "cons_finals"
        match_number   : 2
        bracket_side   : "consolation"
        match_status   : "pending"
      }
    } as $kfinals_2
  
    // -----------------------------------------------------------------------
    // STEP 2: Wire routing FKs now that all match IDs exist
    // -----------------------------------------------------------------------
  
    // PIGTAIL: winner -> champ_r1 match 1 (bottom slot), loser -> eliminated
    db.edit bracket_match {
      field_name = "id"
      field_value = $pigtail_1.id
      data = {
        winner_advances_to_match_id: $cr1_1.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    // CHAMP R1 -> CHAMP QF routing
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_1.id
      data = {
        winner_advances_to_match_id: $cqf_1.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr1_4.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_2.id
      data = {
        winner_advances_to_match_id: $cqf_1.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr1_4.id
        loser_slot_in_next         : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_3.id
      data = {
        winner_advances_to_match_id: $cqf_2.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr1_3.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_4.id
      data = {
        winner_advances_to_match_id: $cqf_2.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr1_3.id
        loser_slot_in_next         : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_5.id
      data = {
        winner_advances_to_match_id: $cqf_3.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr1_2.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_6.id
      data = {
        winner_advances_to_match_id: $cqf_3.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr1_2.id
        loser_slot_in_next         : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_7.id
      data = {
        winner_advances_to_match_id: $cqf_4.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr1_1.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_8.id
      data = {
        winner_advances_to_match_id: $cqf_4.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr1_1.id
        loser_slot_in_next         : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_9.id
      data = {
        winner_advances_to_match_id: $cqf_5.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr1_8.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_10.id
      data = {
        winner_advances_to_match_id: $cqf_5.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr1_8.id
        loser_slot_in_next         : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_11.id
      data = {
        winner_advances_to_match_id: $cqf_6.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr1_7.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_12.id
      data = {
        winner_advances_to_match_id: $cqf_6.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr1_7.id
        loser_slot_in_next         : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_13.id
      data = {
        winner_advances_to_match_id: $cqf_7.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr1_6.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_14.id
      data = {
        winner_advances_to_match_id: $cqf_7.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr1_6.id
        loser_slot_in_next         : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_15.id
      data = {
        winner_advances_to_match_id: $cqf_8.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr1_5.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cr1_16.id
      data = {
        winner_advances_to_match_id: $cqf_8.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr1_5.id
        loser_slot_in_next         : "bottom"
      }
    } as $upd
  
    // CHAMP QF -> CHAMP SF routing
    db.edit bracket_match {
      field_name = "id"
      field_value = $cqf_1.id
      data = {
        winner_advances_to_match_id: $csf_1.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr2_4.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cqf_2.id
      data = {
        winner_advances_to_match_id: $csf_1.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr2_3.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cqf_3.id
      data = {
        winner_advances_to_match_id: $csf_2.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr2_2.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cqf_4.id
      data = {
        winner_advances_to_match_id: $csf_2.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr2_1.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cqf_5.id
      data = {
        winner_advances_to_match_id: $csf_3.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr2_5.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cqf_6.id
      data = {
        winner_advances_to_match_id: $csf_3.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr2_6.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cqf_7.id
      data = {
        winner_advances_to_match_id: $csf_4.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr2_7.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $cqf_8.id
      data = {
        winner_advances_to_match_id: $csf_4.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr2_8.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    // CHAMP SF -> CHAMP FINALS + CONS R4 (SF losers drop to cons_r4)
    db.edit bracket_match {
      field_name = "id"
      field_value = $csf_1.id
      data = {
        winner_advances_to_match_id: $cfinals.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr4_2.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $csf_2.id
      data = {
        winner_advances_to_match_id: $cfinals.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr4_1.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $csf_3.id
      data = {
        winner_advances_to_match_id: $cfinals.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kr4_3.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $csf_4.id
      data = {
        winner_advances_to_match_id: $cfinals.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kr4_4.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    // CONS R1 -> CONS R2 (cons r1 winners fill bottom slot; qf losers fill top)
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr1_1.id
      data = {
        winner_advances_to_match_id: $kr2_1.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr1_2.id
      data = {
        winner_advances_to_match_id: $kr2_2.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr1_3.id
      data = {
        winner_advances_to_match_id: $kr2_3.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr1_4.id
      data = {
        winner_advances_to_match_id: $kr2_4.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr1_5.id
      data = {
        winner_advances_to_match_id: $kr2_5.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr1_6.id
      data = {
        winner_advances_to_match_id: $kr2_6.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr1_7.id
      data = {
        winner_advances_to_match_id: $kr2_7.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr1_8.id
      data = {
        winner_advances_to_match_id: $kr2_8.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    // CONS R2 -> CONS R3
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr2_1.id
      data = {
        winner_advances_to_match_id: $kr3_1.id
        winner_slot_in_next        : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr2_2.id
      data = {
        winner_advances_to_match_id: $kr3_1.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr2_3.id
      data = {
        winner_advances_to_match_id: $kr3_2.id
        winner_slot_in_next        : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr2_4.id
      data = {
        winner_advances_to_match_id: $kr3_2.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr2_5.id
      data = {
        winner_advances_to_match_id: $kr3_3.id
        winner_slot_in_next        : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr2_6.id
      data = {
        winner_advances_to_match_id: $kr3_3.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr2_7.id
      data = {
        winner_advances_to_match_id: $kr3_4.id
        winner_slot_in_next        : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr2_8.id
      data = {
        winner_advances_to_match_id: $kr3_4.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    // CONS R3 -> CONS R4 (cons r3 winners fill bottom; champ sf losers fill top)
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr3_1.id
      data = {
        winner_advances_to_match_id: $kr4_1.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr3_2.id
      data = {
        winner_advances_to_match_id: $kr4_2.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr3_3.id
      data = {
        winner_advances_to_match_id: $kr4_3.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr3_4.id
      data = {
        winner_advances_to_match_id: $kr4_4.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    // CONS R4 -> CONS SF
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr4_1.id
      data = {
        winner_advances_to_match_id: $ksf_1.id
        winner_slot_in_next        : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr4_2.id
      data = {
        winner_advances_to_match_id: $ksf_1.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr4_3.id
      data = {
        winner_advances_to_match_id: $ksf_2.id
        winner_slot_in_next        : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $kr4_4.id
      data = {
        winner_advances_to_match_id: $ksf_2.id
        winner_slot_in_next        : "bottom"
      }
    } as $upd
  
    // CONS SF -> CONS FINALS (winners -> 5th/6th; losers -> 7th/8th)
    db.edit bracket_match {
      field_name = "id"
      field_value = $ksf_1.id
      data = {
        winner_advances_to_match_id: $kfinals_1.id
        winner_slot_in_next        : "top"
        loser_drops_to_match_id    : $kfinals_2.id
        loser_slot_in_next         : "top"
      }
    } as $upd
  
    db.edit bracket_match {
      field_name = "id"
      field_value = $ksf_2.id
      data = {
        winner_advances_to_match_id: $kfinals_1.id
        winner_slot_in_next        : "bottom"
        loser_drops_to_match_id    : $kfinals_2.id
        loser_slot_in_next         : "bottom"
      }
    } as $upd
  }

  response = {
    success        : true
    weight_class_id: $input.weight_class_id
    matches_created: 59
  }
}
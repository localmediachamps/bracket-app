//  Generates the full bracket_match graph for one weight class.
//  Replaces initialize_weight_bracket.xs — ncaa_33 is produced by the generic
//  algorithm with N=32, P=1 pigtail and full consolation (verified against the
//  old validated 61-match structure).
// 
//  Inputs: weight_class_id, tournament_id, template (ncaa_33 | field_N),
//  optional bracket_size override, optional consolation (full|none).
// 
//  Structure (ARCHITECTURE.md sections 2-3):
//    - Seed positions: start [1,2]; expand each s -> s, 2B+1-s until size N.
//    - Pigtails: when C = N + P, pigtail j pairs seeds (N-P+j) vs (N+j),
//      winner occupies seed position (N-P+j) in champ_r1.
//    - Championship: champ_r1..champ_r(K-1), champ_finals (K = log2 N).
//    - Consolation full (K>=4): champ r1 losers -> cons_r1 (paired);
//      champ r2 losers -> cons_r2 vs cons_r1 winners; champ round-k losers
//      (3<=k<=K-2) -> cons_r(2k-2) vs cons_r(2k-3) winners; blood round =
//      cons_r(2K-6); final cons round = cons_r(2K-5) "Consolation Semis";
//      its winners -> place_5, losers -> place_7; SF losers -> place_3.
//    - N=8 (K=3): champ r1 (QF) losers -> cons_r1 (2, Blood Round) ->
//      cons_r2 (1, Consolation Semis); cons_r2 winner -> place_5 (single-slot
//      bye that auto-completes); cons_r1 losers -> place_7; SF losers -> place_3.
//    - N=4 (K=2) or consolation=none: championship + place_3 only.
//    - Byes (C < N): first-round matches with a single participant are stored
//      is_bye=true, match_status=complete and their advancement fires here.
// 
//  DEVIATION: pigtail round_number is 0 (not 1-based) so display_order
//  (round_number*100+match_number) sorts pigtails before champ_r1; champ_r1
//  keeps round_number 1 as required by the scoring config.
// Delete and rebuild the full match graph for a weight class, then run the self-check
function bracket_generate {
  input {
    // Weight class to generate the bracket for
    int weight_class_id
  
    // Tournament the weight class belongs to
    int tournament_id
  
    // Bracket template: ncaa_33 or field_N with N in {4,8,16,32,64}
    text template?="ncaa_33" filters=trim|lower
  
    // Optional championship field size override
    int? bracket_size?
  
    // Consolation mode: full | none (default full)
    text? consolation? filters=trim|lower
  }

  stack {
    // ------------------------------------------------------------------
    // Load competitors and template parameters
    // ------------------------------------------------------------------
    db.query wrestler {
      where = $db.wrestler.weight_class_id == $input.weight_class_id
      sort = {seed: "asc"}
      return = {type: "list"}
      output = ["id", "seed"]
    } as $wrestlers
  
    var $competitor_count {
      value = $wrestlers|count
    }
  
    precondition ($competitor_count >= 2) {
      error_type = "inputerror"
      error = "At least 2 competitors are required to generate a bracket."
    }
  
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
  
    // Resolve bracket size N
    var $n_size {
      value = 0
    }
  
    conditional {
      if ($input.bracket_size != null) {
        var.update $n_size {
          value = $input.bracket_size
        }
      }
    
      elseif ($input.template == "ncaa_33") {
        var.update $n_size {
          value = 32
        }
      }
    
      elseif ($input.template|starts_with:"field_") {
        var $size_parts {
          value = $input.template|split:"_"
        }
      
        var.update $n_size {
          value = ($size_parts[1])|to_int
        }
      }
    }
  
    precondition (($n_size == 4) || ($n_size == 8) || ($n_size == 16) || ($n_size == 32) || ($n_size == 64)) {
      error_type = "inputerror"
      error = "bracket_size must be one of 4, 8, 16, 32, 64 (template '" ~ $input.template ~ "')."
    }
  
    var $k_rounds {
      value = 0
    }
  
    conditional {
      if ($n_size == 4) {
        var.update $k_rounds {
          value = 2
        }
      }
    
      elseif ($n_size == 8) {
        var.update $k_rounds {
          value = 3
        }
      }
    
      elseif ($n_size == 16) {
        var.update $k_rounds {
          value = 4
        }
      }
    
      elseif ($n_size == 32) {
        var.update $k_rounds {
          value = 5
        }
      }
    
      elseif ($n_size == 64) {
        var.update $k_rounds {
          value = 6
        }
      }
    }
  
    // Pigtail count: competitors beyond the championship field size
    var $pigtail_count {
      value = 0
    }
  
    conditional {
      if ($competitor_count > $n_size) {
        var.update $pigtail_count {
          value = $competitor_count - $n_size
        }
      }
    }
  
    precondition ($pigtail_count <= $n_size) {
      error_type = "inputerror"
      error = "Too many competitors (" ~ $competitor_count ~ ") for bracket size " ~ $n_size ~ "."
    }
  
    var $cons_mode {
      value = $input.consolation|first_notnull:"full"
    }
  
    precondition (($cons_mode == "full") || ($cons_mode == "none")) {
      error_type = "inputerror"
      error = "consolation must be 'full' or 'none'."
    }
  
    // N=4 has no consolation rounds regardless of mode
    var $cons_enabled {
      value = ($cons_mode == "full") && ($k_rounds >= 3)
    }
  
    // ------------------------------------------------------------------
    // Guard: refuse to rebuild once results exist; then delete old matches
    // ------------------------------------------------------------------
    db.query bracket_match {
      where = $db.bracket_match.weight_class_id == $input.weight_class_id
      return = {type: "list"}
      output = ["id", "match_status"]
    } as $existing_matches
  
    var $locked_count {
      value = 0
    }
  
    foreach ($existing_matches) {
      each as $em {
        conditional {
          if ($em.match_status == "complete" || $em.match_status == "corrected" || $em.match_status == "in_progress") {
            var.update $locked_count {
              value = $locked_count + 1
            }
          }
        }
      }
    }
  
    precondition ($locked_count == 0) {
      error_type = "inputerror"
      error = "Bracket already has recorded results and cannot be regenerated."
    }
  
    foreach ($existing_matches) {
      each as $em {
        db.del bracket_match {
          field_name = "id"
          field_value = $em.id
        }
      }
    }
  
    // ------------------------------------------------------------------
    // Seed positions: start [1,2]; expand s -> s, 2B+1-s until size N
    // ------------------------------------------------------------------
    var $positions {
      value = [1, 2]
    }
  
    while (($positions|count) < $n_size) {
      each {
        var $next_base {
          value = ($positions|count) * 2
        }
      
        var $next_positions {
          value = []
        }
      
        foreach ($positions) {
          each as $pos {
            array.push $next_positions {
              value = $pos
            }
          
            array.push $next_positions {
              value = $next_base + 1 - $pos
            }
          }
        }
      
        var.update $positions {
          value = $next_positions
        }
      }
    }
  
    var $descriptors {
      value = []
    }
  
    // ------------------------------------------------------------------
    // Pigtails: pigtail j pairs seeds (N-P+j) vs (N+j);
    // winner occupies seed position (N-P+j) in champ_r1
    // ------------------------------------------------------------------
    var $pigtail_pos {
      value = {}
    }
  
    conditional {
      if ($pigtail_count > 0) {
        for ($pigtail_count) {
          each as $jidx {
            var $pj {
              value = $jidx + 1
            }
          
            var $pig_position {
              value = ($n_size - $pigtail_count) + $pj
            }
          
            var $pig_seed_bottom {
              value = $n_size + $pj
            }
          
            // Locate the champ_r1 slot holding this seed position
            var $pos_index {
              value = -1
            }
          
            for ($n_size) {
              each as $pidx {
                conditional {
                  if (($positions[$pidx] == $pig_position) && ($pos_index == -1)) {
                    var.update $pos_index {
                      value = $pidx
                    }
                  }
                }
              }
            }
          
            var $pig_match_number {
              value = (($pos_index / 2)|floor) + 1
            }
          
            var $pig_slot {
              value = (($pos_index|modulus:2) == 0) ? "top" : "bottom"
            }
          
            var.update $pigtail_pos {
              value = $pigtail_pos
                |set:$pig_position:{j: $pj, mn: $pig_match_number, slot: $pig_slot}
            }
          
            var $pig_descriptor {
              value = ```
                {
                  rc : "pigtail"
                  rn : 0
                  rl : "Pigtail"
                  mn : $pj
                  sec: "championship"
                  dor: $pj
                  tt : "seed"
                  ts : $pig_position
                  trc: null
                  tmn: null
                  bt : "seed"
                  bs : $pig_seed_bottom
                  brc: null
                  bmn: null
                  wrc: "champ_r1"
                  wmn: $pig_match_number
                  wsl: $pig_slot
                  lrc: null
                  lmn: null
                  lsl: null
                  tw : $seed_map[$pig_position]
                  bw : $seed_map[$pig_seed_bottom]
                }
                ```
            }
          
            array.push $descriptors {
              value = $pig_descriptor
            }
          }
        }
      }
    }
  
    // ------------------------------------------------------------------
    // Championship rounds k = 1..K
    // ------------------------------------------------------------------
    var $k_minus_1 {
      value = $k_rounds - 1
    }
  
    for ($k_rounds) {
      each as $kidx {
        var $k {
          value = $kidx + 1
        }
      
        var $round_match_count {
          value = ($n_size / (2|pow:$k))|to_int
        }
      
        var $round_code {
          value = ($k == $k_rounds) ? "champ_finals" : ("champ_r" ~ $k)
        }
      
        // Round label: named by distance to the final when close
        // (Championship / Semifinals / Quarterfinals), otherwise ordinal
        // from the start of the bracket (First Round, Second Round, ...).
        var $dist {
          value = $k_rounds - $k
        }
      
        var $round_label {
          value = "First Round"
        }
      
        conditional {
          if ($dist == 0) {
            var.update $round_label {
              value = "Championship"
            }
          }
        
          elseif ($dist == 1) {
            var.update $round_label {
              value = "Semifinals"
            }
          }
        
          elseif ($dist == 2) {
            var.update $round_label {
              value = "Quarterfinals"
            }
          }
        
          elseif ($k == 1) {
            var.update $round_label {
              value = "First Round"
            }
          }
        
          elseif ($k == 2) {
            var.update $round_label {
              value = "Second Round"
            }
          }
        
          elseif ($k == 3) {
            var.update $round_label {
              value = "Third Round"
            }
          }
        
          elseif ($k == 4) {
            var.update $round_label {
              value = "Fourth Round"
            }
          }
        
          elseif ($k == 5) {
            var.update $round_label {
              value = "Fifth Round"
            }
          }
        
          else {
            var.update $round_label {
              value = "Sixth Round"
            }
          }
        }
      
        for ($round_match_count) {
          each as $iidx {
            var $i {
              value = $iidx + 1
            }
          
            var $is_odd {
              value = ($i|modulus:2) == 1
            }
          
            var $slot_of_i {
              value = $is_odd ? "top" : "bottom"
            }
          
            var $ceil_half_i {
              value = (($i + 1) / 2)|floor
            }
          
            // --- sources ---
            var $tt {
              value = null
            }
          
            var $ts {
              value = null
            }
          
            var $trc {
              value = null
            }
          
            var $tmn {
              value = null
            }
          
            var $tw {
              value = null
            }
          
            var $bt {
              value = null
            }
          
            var $bs {
              value = null
            }
          
            var $brc {
              value = null
            }
          
            var $bmn {
              value = null
            }
          
            var $bw {
              value = null
            }
          
            conditional {
              if ($k == 1) {
                // Seed-sourced slots (with pigtail override)
                var $top_seed_pos {
                  value = $positions[(2 * $i) - 2]
                }
              
                var $bottom_seed_pos {
                  value = $positions[(2 * $i) - 1]
                }
              
                conditional {
                  if ($pigtail_pos|has:$top_seed_pos) {
                    var $pig_info_top {
                      value = $pigtail_pos[$top_seed_pos]
                    }
                  
                    var.update $tt {
                      value = "match_winner"
                    }
                  
                    var.update $trc {
                      value = "pigtail"
                    }
                  
                    var.update $tmn {
                      value = $pig_info_top.j
                    }
                  }
                
                  else {
                    var.update $tt {
                      value = "seed"
                    }
                  
                    var.update $ts {
                      value = $top_seed_pos
                    }
                  
                    conditional {
                      if ($top_seed_pos <= $competitor_count) {
                        var.update $tw {
                          value = $seed_map[$top_seed_pos]
                        }
                      }
                    }
                  }
                }
              
                conditional {
                  if ($pigtail_pos|has:$bottom_seed_pos) {
                    var $pig_info_bottom {
                      value = $pigtail_pos[$bottom_seed_pos]
                    }
                  
                    var.update $bt {
                      value = "match_winner"
                    }
                  
                    var.update $brc {
                      value = "pigtail"
                    }
                  
                    var.update $bmn {
                      value = $pig_info_bottom.j
                    }
                  }
                
                  else {
                    var.update $bt {
                      value = "seed"
                    }
                  
                    var.update $bs {
                      value = $bottom_seed_pos
                    }
                  
                    conditional {
                      if ($bottom_seed_pos <= $competitor_count) {
                        var.update $bw {
                          value = $seed_map[$bottom_seed_pos]
                        }
                      }
                    }
                  }
                }
              }
            
              else {
                // Winners of the two feeding matches from the previous round
                var.update $tt {
                  value = "match_winner"
                }
              
                var.update $trc {
                  value = "champ_r" ~ ($k - 1)
                }
              
                var.update $tmn {
                  value = (2 * $i) - 1
                }
              
                var.update $bt {
                  value = "match_winner"
                }
              
                var.update $brc {
                  value = "champ_r" ~ ($k - 1)
                }
              
                var.update $bmn {
                  value = 2 * $i
                }
              }
            }
          
            // --- winner destination ---
            var $wrc {
              value = null
            }
          
            var $wmn {
              value = null
            }
          
            var $wsl {
              value = null
            }
          
            conditional {
              if ($k < $k_rounds) {
                var.update $wrc {
                  value = (($k + 1) == $k_rounds) ? "champ_finals" : ("champ_r" ~ ($k + 1))
                }
              
                var.update $wmn {
                  value = $ceil_half_i
                }
              
                var.update $wsl {
                  value = $slot_of_i
                }
              }
            }
          
            // --- loser destination ---
            var $lrc {
              value = null
            }
          
            var $lmn {
              value = null
            }
          
            var $lsl {
              value = null
            }
          
            conditional {
              if ($k < $k_rounds) {
                conditional {
                  if ($k == $k_minus_1) {
                    // Semifinal losers -> 3rd place match
                    var.update $lrc {
                      value = "place_3"
                    }
                  
                    var.update $lmn {
                      value = 1
                    }
                  
                    var.update $lsl {
                      value = ($i == 1) ? "top" : "bottom"
                    }
                  }
                
                  elseif ($cons_enabled) {
                    conditional {
                      if ($k_rounds == 3) {
                        // N=8: QF (round 1) losers -> cons_r1 paired
                        var.update $lrc {
                          value = "cons_r1"
                        }
                      
                        var.update $lmn {
                          value = $ceil_half_i
                        }
                      
                        var.update $lsl {
                          value = $slot_of_i
                        }
                      }
                    
                      else {
                        conditional {
                          if ($k == 1) {
                            var.update $lrc {
                              value = "cons_r1"
                            }
                          
                            var.update $lmn {
                              value = $ceil_half_i
                            }
                          
                            var.update $lsl {
                              value = $slot_of_i
                            }
                          }
                        
                          elseif ($k == 2) {
                            var.update $lrc {
                              value = "cons_r2"
                            }
                          
                            var.update $lmn {
                              value = $i
                            }
                          
                            var.update $lsl {
                              value = "top"
                            }
                          }
                        
                          else {
                            // champ round-k losers (3<=k<=K-2) -> cons_r(2k-2) top
                            var.update $lrc {
                              value = "cons_r" ~ ((2 * $k) - 2)
                            }
                          
                            var.update $lmn {
                              value = $i
                            }
                          
                            var.update $lsl {
                              value = "top"
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          
            array.push $descriptors {
              value = {
                rc : $round_code
                rn : $k
                rl : $round_label
                mn : $i
                sec: "championship"
                dor: ($k * 100) + $i
                tt : $tt
                ts : $ts
                trc: $trc
                tmn: $tmn
                bt : $bt
                bs : $bs
                brc: $brc
                bmn: $bmn
                wrc: $wrc
                wmn: $wmn
                wsl: $wsl
                lrc: $lrc
                lmn: $lmn
                lsl: $lsl
                tw : $tw
                bw : $bw
              }
            }
          }
        }
      }
    }
  
    // ------------------------------------------------------------------
    // Consolation rounds (full mode only)
    // ------------------------------------------------------------------
    conditional {
      if ($cons_enabled) {
        conditional {
          if ($k_rounds == 3) {
            // N=8 special case: cons_r1 (2 matches, Blood Round),
            // cons_r2 (1 match, Consolation Semis)
            for (2) {
              each as $iidx {
                var $i {
                  value = $iidx + 1
                }
              
                var $i_slot {
                  value = ($i == 1) ? "top" : "bottom"
                }
              
                array.push $descriptors {
                  value = {
                    rc : "cons_r1"
                    rn : 1
                    rl : "Blood Round"
                    mn : $i
                    sec: "consolation"
                    dor: 10100 + $i
                    tt : "match_loser"
                    ts : null
                    trc: "champ_r1"
                    tmn: (2 * $i) - 1
                    bt : "match_loser"
                    bs : null
                    brc: "champ_r1"
                    bmn: 2 * $i
                    wrc: "cons_r2"
                    wmn: 1
                    wsl: $i_slot
                    lrc: "place_7"
                    lmn: 1
                    lsl: $i_slot
                    tw : null
                    bw : null
                  }
                }
              }
            }
          
            array.push $descriptors {
              value = {
                rc : "cons_r2"
                rn : 2
                rl : "Consolation Semis"
                mn : 1
                sec: "consolation"
                dor: 10201
                tt : "match_winner"
                ts : null
                trc: "cons_r1"
                tmn: 1
                bt : "match_winner"
                bs : null
                brc: "cons_r1"
                bmn: 2
                wrc: "place_5"
                wmn: 1
                wsl: "top"
                lrc: null
                lmn: null
                lsl: null
                tw : null
                bw : null
              }
            }
          }
        
          else {
            // K >= 4: general staggered consolation, L = 2K-5 rounds
            var $last_cons_round {
              value = (2 * $k_rounds) - 5
            }
          
            var $blood_round {
              value = (2 * $k_rounds) - 6
            }
          
            for ($last_cons_round) {
              each as $nidx {
                var $n {
                  value = $nidx + 1
                }
              
                var $n_is_odd {
                  value = ($n|modulus:2) == 1
                }
              
                var $cons_label {
                  value = "Consolation R" ~ $n
                }
              
                conditional {
                  if ($n == $last_cons_round) {
                    var.update $cons_label {
                      value = "Consolation Semis"
                    }
                  }
                
                  elseif ($n == $blood_round) {
                    var.update $cons_label {
                      value = "Blood Round"
                    }
                  }
                }
              
                // Round kind + match count
                var $cons_kind {
                  value = "pair"
                }
              
                var $cons_k {
                  value = 0
                }
              
                conditional {
                  if ($n <= 2) {
                    var.update $cons_kind {
                      value = ($n == 1) ? "r1" : "r2"
                    }
                  }
                
                  elseif ($n_is_odd) {
                    var.update $cons_kind {
                      value = "pair"
                    }
                  
                    var.update $cons_k {
                      value = (($n + 3) / 2)|floor
                    }
                  }
                
                  else {
                    var.update $cons_kind {
                      value = "drop"
                    }
                  
                    var.update $cons_k {
                      value = (($n + 2) / 2)|floor
                    }
                  }
                }
              
                var $cons_match_count {
                  value = 0
                }
              
                conditional {
                  if (($n == 1) || ($n == 2)) {
                    var.update $cons_match_count {
                      value = ($n_size / 4)|to_int
                    }
                  }
                
                  else {
                    var.update $cons_match_count {
                      value = ($n_size / (2|pow:$cons_k))|to_int
                    }
                  }
                }
              
                for ($cons_match_count) {
                  each as $jidx {
                    var $j {
                      value = $jidx + 1
                    }
                  
                    var $j_is_odd {
                      value = ($j|modulus:2) == 1
                    }
                  
                    var $slot_of_j {
                      value = $j_is_odd ? "top" : "bottom"
                    }
                  
                    var $ceil_half_j {
                      value = (($j + 1) / 2)|floor
                    }
                  
                    conditional {
                      if ($cons_kind == "r1") {
                        // cons_r1: champ_r1 losers paired within the quarter
                        array.push $descriptors {
                          value = {
                            rc : "cons_r1"
                            rn : 1
                            rl : $cons_label
                            mn : $j
                            sec: "consolation"
                            dor: 10100 + $j
                            tt : "match_loser"
                            ts : null
                            trc: "champ_r1"
                            tmn: (2 * $j) - 1
                            bt : "match_loser"
                            bs : null
                            brc: "champ_r1"
                            bmn: 2 * $j
                            wrc: "cons_r2"
                            wmn: $j
                            wsl: "bottom"
                            lrc: null
                            lmn: null
                            lsl: null
                            tw : null
                            bw : null
                          }
                        }
                      }
                    
                      elseif ($cons_kind == "r2") {
                        // cons_r2: champ_r2 losers (top) vs cons_r1 winners (bottom)
                        array.push $descriptors {
                          value = {
                            rc : "cons_r2"
                            rn : 2
                            rl : $cons_label
                            mn : $j
                            sec: "consolation"
                            dor: 10200 + $j
                            tt : "match_loser"
                            ts : null
                            trc: "champ_r2"
                            tmn: $j
                            bt : "match_winner"
                            bs : null
                            brc: "cons_r1"
                            bmn: $j
                            wrc: "cons_r3"
                            wmn: $ceil_half_j
                            wsl: $slot_of_j
                            lrc: null
                            lmn: null
                            lsl: null
                            tw : null
                            bw : null
                          }
                        }
                      }
                    
                      elseif ($cons_kind == "pair") {
                        // Pairing round: winners of previous cons round
                        var $pair_wrc {
                          value = "cons_r" ~ ($n + 1)
                        }
                      
                        var $pair_wmn {
                          value = $j
                        }
                      
                        var $pair_wsl {
                          value = "bottom"
                        }
                      
                        var $pair_lrc {
                          value = null
                        }
                      
                        var $pair_lmn {
                          value = null
                        }
                      
                        var $pair_lsl {
                          value = null
                        }
                      
                        conditional {
                          if ($n == $last_cons_round) {
                            // Final cons round: winners -> place_5, losers -> place_7
                            var.update $pair_wrc {
                              value = "place_5"
                            }
                          
                            var.update $pair_wmn {
                              value = 1
                            }
                          
                            var.update $pair_wsl {
                              value = ($j == 1) ? "top" : "bottom"
                            }
                          
                            var.update $pair_lrc {
                              value = "place_7"
                            }
                          
                            var.update $pair_lmn {
                              value = 1
                            }
                          
                            var.update $pair_lsl {
                              value = ($j == 1) ? "top" : "bottom"
                            }
                          }
                        }
                      
                        array.push $descriptors {
                          value = {
                            rc : "cons_r" ~ $n
                            rn : $n
                            rl : $cons_label
                            mn : $j
                            sec: "consolation"
                            dor: (10000 + ($n * 100)) + $j
                            tt : "match_winner"
                            ts : null
                            trc: "cons_r" ~ ($n - 1)
                            tmn: (2 * $j) - 1
                            bt : "match_winner"
                            bs : null
                            brc: "cons_r" ~ ($n - 1)
                            bmn: 2 * $j
                            wrc: $pair_wrc
                            wmn: $pair_wmn
                            wsl: $pair_wsl
                            lrc: $pair_lrc
                            lmn: $pair_lmn
                            lsl: $pair_lsl
                            tw : null
                            bw : null
                          }
                        }
                      }
                    
                      else {
                        // Drop-in round: champ round-k losers (top) vs cons winners (bottom)
                        array.push $descriptors {
                          value = {
                            rc : "cons_r" ~ $n
                            rn : $n
                            rl : $cons_label
                            mn : $j
                            sec: "consolation"
                            dor: (10000 + ($n * 100)) + $j
                            tt : "match_loser"
                            ts : null
                            trc: "champ_r" ~ $cons_k
                            tmn: $j
                            bt : "match_winner"
                            bs : null
                            brc: "cons_r" ~ ($n - 1)
                            bmn: $j
                            wrc: "cons_r" ~ ($n + 1)
                            wmn: $ceil_half_j
                            wsl: $slot_of_j
                            lrc: null
                            lmn: null
                            lsl: null
                            tw : null
                            bw : null
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
    }
  
    // ------------------------------------------------------------------
    // Placement matches
    // ------------------------------------------------------------------
    array.push $descriptors {
      value = {
        rc : "place_3"
        rn : 1
        rl : "3rd Place"
        mn : 1
        sec: "placement"
        dor: 5001
        tt : "match_loser"
        ts : null
        trc: "champ_r" ~ $k_minus_1
        tmn: 1
        bt : "match_loser"
        bs : null
        brc: "champ_r" ~ $k_minus_1
        bmn: 2
        wrc: null
        wmn: null
        wsl: null
        lrc: null
        lmn: null
        lsl: null
        tw : null
        bw : null
      }
    }
  
    conditional {
      if ($cons_enabled) {
        conditional {
          if ($k_rounds == 3) {
            // N=8: place_5 is a single-slot bye fed by the consolation final
            array.push $descriptors {
              value = {
                rc : "place_5"
                rn : 2
                rl : "5th Place"
                mn : 1
                sec: "placement"
                dor: 5002
                tt : "match_winner"
                ts : null
                trc: "cons_r2"
                tmn: 1
                bt : null
                bs : null
                brc: null
                bmn: null
                wrc: null
                wmn: null
                wsl: null
                lrc: null
                lmn: null
                lsl: null
                tw : null
                bw : null
              }
            }
          
            array.push $descriptors {
              value = {
                rc : "place_7"
                rn : 3
                rl : "7th Place"
                mn : 1
                sec: "placement"
                dor: 5003
                tt : "match_loser"
                ts : null
                trc: "cons_r1"
                tmn: 1
                bt : "match_loser"
                bs : null
                brc: "cons_r1"
                bmn: 2
                wrc: null
                wmn: null
                wsl: null
                lrc: null
                lmn: null
                lsl: null
                tw : null
                bw : null
              }
            }
          }
        
          else {
            var $final_cons_code {
              value = "cons_r" ~ ((2 * $k_rounds) - 5)
            }
          
            array.push $descriptors {
              value = {
                rc : "place_5"
                rn : 2
                rl : "5th Place"
                mn : 1
                sec: "placement"
                dor: 5002
                tt : "match_winner"
                ts : null
                trc: $final_cons_code
                tmn: 1
                bt : "match_winner"
                bs : null
                brc: $final_cons_code
                bmn: 2
                wrc: null
                wmn: null
                wsl: null
                lrc: null
                lmn: null
                lsl: null
                tw : null
                bw : null
              }
            }
          
            array.push $descriptors {
              value = {
                rc : "place_7"
                rn : 3
                rl : "7th Place"
                mn : 1
                sec: "placement"
                dor: 5003
                tt : "match_loser"
                ts : null
                trc: $final_cons_code
                tmn: 1
                bt : "match_loser"
                bs : null
                brc: $final_cons_code
                bmn: 2
                wrc: null
                wmn: null
                wsl: null
                lrc: null
                lmn: null
                lsl: null
                tw : null
                bw : null
              }
            }
          }
        }
      }
    }
  
    // ------------------------------------------------------------------
    // PASS 1: create all match rows, capture ids keyed by round_code|mn
    // ------------------------------------------------------------------
    var $id_map {
      value = {}
    }
  
    foreach ($descriptors) {
      each as $d {
        db.add bracket_match {
          data = {
            tournament_id            : $input.tournament_id
            weight_class_id          : $input.weight_class_id
            round_code               : $d.rc
            round_number             : $d.rn
            round_label              : $d.rl
            match_number             : $d.mn
            display_order            : $d.dor
            bracket_section          : $d.sec
            top_source_type          : $d.tt
            top_source_seed          : $d.ts
            bottom_source_type       : $d.bt
            bottom_source_seed       : $d.bs
            actual_top_wrestler_id   : $d.tw
            actual_bottom_wrestler_id: $d.bw
            winner_slot_in_next      : $d.wsl
            loser_slot_in_next       : $d.lsl
            match_status             : "pending"
            version                  : 1
            is_bye                   : false
          }
        } as $new_match
      
        var $dkey {
          value = $d.rc ~ "|" ~ $d.mn
        }
      
        var.update $id_map {
          value = $id_map|set:$dkey:$new_match.id
        }
      }
    }
  
    // ------------------------------------------------------------------
    // PASS 2: wire source/routing foreign keys
    // ------------------------------------------------------------------
    foreach ($descriptors) {
      each as $d {
        var $self_key {
          value = $d.rc ~ "|" ~ $d.mn
        }
      
        var $self_id {
          value = $id_map[$self_key]
        }
      
        var $top_source_id {
          value = null
        }
      
        conditional {
          if ($d.trc != null) {
            var $top_source_key {
              value = $d.trc ~ "|" ~ $d.tmn
            }
          
            var.update $top_source_id {
              value = $id_map[$top_source_key]
            }
          }
        }
      
        var $bottom_source_id {
          value = null
        }
      
        conditional {
          if ($d.brc != null) {
            var $bottom_source_key {
              value = $d.brc ~ "|" ~ $d.bmn
            }
          
            var.update $bottom_source_id {
              value = $id_map[$bottom_source_key]
            }
          }
        }
      
        var $winner_dest_id {
          value = null
        }
      
        conditional {
          if ($d.wrc != null) {
            var $winner_dest_key {
              value = $d.wrc ~ "|" ~ $d.wmn
            }
          
            var.update $winner_dest_id {
              value = $id_map[$winner_dest_key]
            }
          }
        }
      
        var $loser_dest_id {
          value = null
        }
      
        conditional {
          if ($d.lrc != null) {
            var $loser_dest_key {
              value = $d.lrc ~ "|" ~ $d.lmn
            }
          
            var.update $loser_dest_id {
              value = $id_map[$loser_dest_key]
            }
          }
        }
      
        db.edit bracket_match {
          field_name = "id"
          field_value = $self_id
          data = {
            top_source_match_id        : $top_source_id
            bottom_source_match_id     : $bottom_source_id
            winner_advances_to_match_id: $winner_dest_id
            loser_drops_to_match_id    : $loser_dest_id
          }
        } as $wired_match
      }
    }
  
    // ------------------------------------------------------------------
    // PASS 3: resolve byes in topological order (championship section).
    // A match whose slots can never both fill becomes a completed bye and
    // its winner (if any) advances immediately.
    // ------------------------------------------------------------------
    var $empty_byes {
      value = {}
    }
  
    foreach ($descriptors) {
      each as $d {
        conditional {
          if ($d.sec == "championship") {
            var $bye_key {
              value = $d.rc ~ "|" ~ $d.mn
            }
          
            var $bye_match_id {
              value = $id_map[$bye_key]
            }
          
            db.get bracket_match {
              field_name = "id"
              field_value = $bye_match_id
            } as $bm
          
            conditional {
              if ($bm.match_status == "pending") {
                var $cur_top {
                  value = $bm.actual_top_wrestler_id
                }
              
                var $cur_bottom {
                  value = $bm.actual_bottom_wrestler_id
                }
              
                // Can the empty top slot ever produce a participant?
                var $top_dead {
                  value = false
                }
              
                conditional {
                  if ($cur_top == null) {
                    conditional {
                      if ($d.tt == null) {
                        var.update $top_dead {
                          value = true
                        }
                      }
                    
                      elseif ($d.tt == "seed") {
                        conditional {
                          if (($d.ts == null) || ($d.ts > $competitor_count)) {
                            var.update $top_dead {
                              value = true
                            }
                          }
                        }
                      }
                    
                      else {
                        var $top_dead_key {
                          value = $d.trc ~ "|" ~ $d.tmn
                        }
                      
                        conditional {
                          if ($empty_byes|has:$top_dead_key) {
                            var.update $top_dead {
                              value = true
                            }
                          }
                        }
                      }
                    }
                  }
                }
              
                // Can the empty bottom slot ever produce a participant?
                var $bottom_dead {
                  value = false
                }
              
                conditional {
                  if ($cur_bottom == null) {
                    conditional {
                      if ($d.bt == null) {
                        var.update $bottom_dead {
                          value = true
                        }
                      }
                    
                      elseif ($d.bt == "seed") {
                        conditional {
                          if (($d.bs == null) || ($d.bs > $competitor_count)) {
                            var.update $bottom_dead {
                              value = true
                            }
                          }
                        }
                      }
                    
                      else {
                        var $bottom_dead_key {
                          value = $d.brc ~ "|" ~ $d.bmn
                        }
                      
                        conditional {
                          if ($empty_byes|has:$bottom_dead_key) {
                            var.update $bottom_dead {
                              value = true
                            }
                          }
                        }
                      }
                    }
                  }
                }
              
                var $both_dead {
                  value = ($cur_top == null) && ($cur_bottom == null) && $top_dead && $bottom_dead
                }
              
                var $only_top {
                  value = ($cur_top != null) && ($cur_bottom == null) && $bottom_dead
                }
              
                var $only_bottom {
                  value = ($cur_bottom != null) && ($cur_top == null) && $top_dead
                }
              
                conditional {
                  if ($both_dead) {
                    // Empty bye: completes with no winner; downstream cascades
                    db.edit bracket_match {
                      field_name = "id"
                      field_value = $bye_match_id
                      data = {
                        is_bye      : true
                        match_status: "complete"
                        completed_at: "now"
                        updated_at  : "now"
                      }
                    } as $empty_bye_upd
                  
                    var.update $empty_byes {
                      value = $empty_byes|set:$bye_key:true
                    }
                  }
                
                  elseif ($only_top || $only_bottom) {
                    var $bye_winner_id {
                      value = $only_top ? $cur_top : $cur_bottom
                    }
                  
                    db.edit bracket_match {
                      field_name = "id"
                      field_value = $bye_match_id
                      data = {
                        is_bye                   : true
                        match_status             : "complete"
                        actual_winner_wrestler_id: $bye_winner_id
                        completed_at             : "now"
                        updated_at               : "now"
                      }
                    } as $bye_upd
                  
                    conditional {
                      if (($bm.winner_advances_to_match_id != null) && ($bye_winner_id != null)) {
                        var $adv_field {
                          value = "actual_" ~ $bm.winner_slot_in_next ~ "_wrestler_id"
                        }
                      
                        var $adv_payload {
                          value = {}|set:$adv_field:$bye_winner_id
                        }
                      
                        db.patch bracket_match {
                          field_name = "id"
                          field_value = $bm.winner_advances_to_match_id
                          data = $adv_payload
                        } as $bye_adv
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
  
    // ------------------------------------------------------------------
    // Persist template metadata on the weight class
    // ------------------------------------------------------------------
    db.edit weight_class {
      field_name = "id"
      field_value = $input.weight_class_id
      data = {
        bracket_template: $input.template
        bracket_size    : $n_size
        competitor_count: $competitor_count
      }
    } as $wc_upd
  
    // ------------------------------------------------------------------
    // Self-check and summary
    // ------------------------------------------------------------------
    function.run bracket_self_check {
      input = {weight_class_id: $input.weight_class_id}
    } as $check
  
    var $result {
      value = {
        matches_created: $descriptors|count
        valid          : $check.valid
        issues         : $check.issues
        match_id_map   : {
          total        : $descriptors|count
          champ_finals : $id_map["champ_finals|1"]
          place_3      : $id_map["place_3|1"]
          place_5      : $id_map["place_5|1"]
          place_7      : $id_map["place_7|1"]
        }
      }
    }
  }

  response = $result
}
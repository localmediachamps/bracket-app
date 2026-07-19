//   Generates the full bracket_match graph for one weight class.
//   Replaces initialize_weight_bracket.xs — ncaa_33 is produced by the generic
//   algorithm with N=32, P=1 pigtail and full consolation (structure verified
//   against the official 2026 NCAA Division I bracket bout numbers).
// 
//   Inputs: weight_class_id, tournament_id, template (ncaa_33 | field_N),
//   optional bracket_size override, optional consolation (full|none).
// 
//   Structure (ARCHITECTURE.md sections 2-3):
//     - Seed positions: start [1,2]; expand each s -> s, 2B+1-s until size N.
//       champ_r1 match i pairs positions[2i-2] vs positions[2i-1]; later champ
//       rounds pair adjacent feeding matches (pods of 4 seeds).
//     - Pigtails: when C = N + P, pigtail j pairs seeds (N-P+j) vs (N+j),
//       winner occupies seed position (N-P+j) in champ_r1.
//     - Championship: champ_r1..champ_r(K-1), champ_finals (K = log2 N).
//     - Consolation full (K>=3): champ r1 losers -> cons_r1 (adjacent pairs);
//       champ round-k losers (2<=k<=K-3) drop into cons_r(2k-2) FULLY REVERSED
//       vs the previous cons round's winners; pairing rounds cons_r(2k-1) pair
//       adjacent winners of cons_r(2k-2); QF losers -> Blood Round cons_r(2K-6)
//       PAIR-SWAPPED (blood #1 vs L(qf #2), #2 vs L(qf #1), ...); Consolation
//       Semis cons_r(2K-5) pair adjacent blood winners; Consolation Finals
//       (the 581/582 matches) = W(semis) vs L(champ SF) CROSS-HALF.
//     - Consolation Finals round code: cons_r2 for K=3 (the cons semis double
//       as the 581/582 matches for N=8), cons_r6 for K=4/5, cons_r8 for K=6.
//     - place_3 = W(cons finals) vs W(cons finals); place_5 = the losers;
//       place_7 = losers of the two matches feeding the cons finals' top slots
//       (cons semis for K>=4, cons_r1 for K=3).
//     - Pigtail loser drops to a consolation pigtail vs the loser of the mirror
//       champ_r1 match (m_j + N/4, wrapped into the field); the cons pigtail
//       winner takes the mirror loser's slot in cons_r1.
//     - N=4 (K=2) or consolation=none: championship + place_3 (SF losers) only.
//     - Byes (C < N): first-round matches with a single participant are stored
//       is_bye=true, match_status=complete and their advancement fires here.
//  
//   DEVIATION: pigtail round_number is 0 (not 1-based) so display_order
//   (round_number*100+match_number) sorts pigtails before champ_r1; champ_r1
//   keeps round_number 1 as required by the scoring config.
//  Delete and rebuild the full match graph for a weight class, then run the self-check
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
  
    // Consolation geometry: quarter/half field sizes and the round codes
    // that vary by K. Blood round = cons_r(2K-6), Consolation Semis =
    // cons_r(2K-5); the Consolation Finals (581/582 matches) are cons_r2
    // for K=3, cons_r6 for K=4/5 and cons_r8 for K=6.
    var $n_quarter {
      value = ($n_size / 4)|to_int
    }
  
    var $n_half {
      value = ($n_size / 2)|to_int
    }
  
    var $blood_code {
      value = "cons_r" ~ ((2 * $k_rounds) - 6)
    }
  
    var $semis_code {
      value = "cons_r" ~ ((2 * $k_rounds) - 5)
    }
  
    var $cons_finals_code {
      value = "cons_r2"
    }
  
    var $cons_finals_rn {
      value = 2
    }
  
    conditional {
      if (($k_rounds == 4) || ($k_rounds == 5)) {
        var.update $cons_finals_code {
          value = "cons_r6"
        }
      
        var.update $cons_finals_rn {
          value = 6
        }
      }
    
      elseif ($k_rounds >= 6) {
        var.update $cons_finals_code {
          value = "cons_r" ~ ((2 * $k_rounds) - 4)
        }
      
        var.update $cons_finals_rn {
          value = (2 * $k_rounds) - 4
        }
      }
    }
  
    // Pigtail consolation wiring maps (filled in the pigtail loop):
    // $mirror_map: champ_r1 match number -> pigtail j (loser detour)
    // $cons_pig_slot_map: "cons_r1 mn|slot" -> pigtail j (slot replacement)
    // $cons_pig_list: one entry per pigtail for descriptor generation
    var $mirror_map {
      value = {}
    }
  
    var $cons_pig_slot_map {
      value = {}
    }
  
    var $cons_pig_list {
      value = []
    }
  
    // Champ r1 -> cons_r1 slot assignment. The drop ORDER depends only on
    // champ r1's match count (the verified R-cycle): 4 matches (R8) = flip
    // within halves (2,1,4,3); 8 (R16) = full flip; 16 (R32) = straight;
    // 32 (R64) = swap halves preserving order (17..32, 1..16). Pairing
    // inside cons_r1 is adjacent in the RESULTING order. Each operation is
    // an involution, so one mapping serves both directions.
    var $r1_cons_mn_of {
      value = {}
    }
  
    var $r1_cons_slot_of {
      value = {}
    }
  
    var $r1_match_at_pos {
      value = {}
    }
  
    for ($n_half) {
      each as $ridx {
        var $ri {
          value = $ridx + 1
        }
      
        var $rpos {
          value = $ri
        }
      
        conditional {
          if ($n_half == 4) {
            var.update $rpos {
              value = (($ri|modulus:2) == 1) ? ($ri + 1) : ($ri - 1)
            }
          }
        
          elseif ($n_half == 8) {
            var.update $rpos {
              value = 9 - $ri
            }
          }
        
          elseif ($n_half == 32) {
            conditional {
              if ($ri <= 16) {
                var.update $rpos {
                  value = $ri + 16
                }
              }
            
              else {
                var.update $rpos {
                  value = $ri - 16
                }
              }
            }
          }
        }
      
        var.update $r1_match_at_pos {
          value = $r1_match_at_pos|set:$rpos:$ri
        }
      
        var $r_cons_mn {
          value = (($rpos + 1) / 2)|floor
        }
      
        var $r_cons_slot {
          value = (($rpos|modulus:2) == 1) ? "top" : "bottom"
        }
      
        var.update $r1_cons_mn_of {
          value = $r1_cons_mn_of|set:$ri:$r_cons_mn
        }
      
        var.update $r1_cons_slot_of {
          value = $r1_cons_slot_of|set:$ri:$r_cons_slot
        }
      }
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
          
            // Mirror champ_r1 match: one quarter of the field ahead of the
            // match this pigtail feeds, wrapped into the champ_r1 range.
            // (ncaa_33: pigtail feeds match 1 -> mirror = 1 + 8 = 9.)
            var $mirror_raw {
              value = (($pig_match_number - 1) + $n_quarter)|modulus:$n_half
            }
          
            var $mirror_mn {
              value = $mirror_raw + 1
            }
          
            // The mirror loser's cons_r1 slot follows the R-cycle order
            var $cons_mn {
              value = $r1_cons_mn_of[$mirror_mn]
            }
          
            var $cons_slot {
              value = $r1_cons_slot_of[$mirror_mn]
            }
          
            var.update $mirror_map {
              value = $mirror_map|set:$pig_match_number:$pj
            }
          
            var $cons_pig_key {
              value = $cons_mn ~ "|" ~ $cons_slot
            }
          
            var.update $cons_pig_slot_map {
              value = $cons_pig_slot_map|set:$cons_pig_key:$pj
            }
          
            array.push $cons_pig_list {
              value = {
                j     : $pj
                mirror: $mirror_mn
                cmn   : $cons_mn
                csl   : $cons_slot
              }
            }
          
            // The pigtail loser drops to the consolation pigtail (full mode)
            var $pig_lrc {
              value = null
            }
          
            var $pig_lmn {
              value = null
            }
          
            var $pig_lsl {
              value = null
            }
          
            conditional {
              if ($cons_enabled) {
                var.update $pig_lrc {
                  value = "cons_pigtail"
                }
              
                var.update $pig_lmn {
                  value = $pj
                }
              
                var.update $pig_lsl {
                  value = "top"
                }
              }
            }
          
            array.push $descriptors {
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
                  lrc: $pig_lrc
                  lmn: $pig_lmn
                  lsl: $pig_lsl
                  tw : $seed_map[$pig_position]
                  bw : $seed_map[$pig_seed_bottom]
                }
                ```
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
                    // Semifinal losers
                    conditional {
                      if ($cons_enabled) {
                        // cross-half into the Consolation Finals (581/582):
                        // SF #1 loser -> finals #2, SF #2 loser -> finals #1
                        var.update $lrc {
                          value = $cons_finals_code
                        }
                      
                        var.update $lmn {
                          value = 3 - $i
                        }
                      
                        var.update $lsl {
                          value = "bottom"
                        }
                      }
                    
                      else {
                        // no consolation: SF losers -> 3rd place match
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
                    }
                  }
                
                  elseif ($cons_enabled) {
                    conditional {
                      if ($k == 1) {
                        conditional {
                          if ($mirror_map|has:$i) {
                            // pigtail mirror match: loser drops to the
                            // consolation pigtail instead of cons_r1
                            var.update $lrc {
                              value = "cons_pigtail"
                            }
                          
                            var.update $lmn {
                              value = $mirror_map[$i]
                            }
                          
                            var.update $lsl {
                              value = "bottom"
                            }
                          }
                        
                          else {
                            // champ_r1 losers -> cons_r1 in the R-cycle
                            // order for champ r1's match count
                            var.update $lrc {
                              value = "cons_r1"
                            }
                          
                            var.update $lmn {
                              value = $r1_cons_mn_of[$i]
                            }
                          
                            var.update $lsl {
                              value = $r1_cons_slot_of[$i]
                            }
                          }
                        }
                      }
                    
                      else {
                        // champ round-k losers (2<=k<=K-2) -> cons_r(2k-2)
                        // bottom slot. The drop ORDER depends only on the
                        // champ round's match count (the R-cycle):
                        // 4 matches (R8) = flip within halves (2,1,4,3);
                        // 8 (R16) = full flip; 16 (R32) = straight;
                        // 32 (R64) = swap halves preserving order.
                        var.update $lrc {
                          value = "cons_r" ~ ((2 * $k) - 2)
                        }
                      
                        var.update $lsl {
                          value = "bottom"
                        }
                      
                        conditional {
                          if ($round_match_count == 4) {
                            var.update $lmn {
                              value = $is_odd ? ($i + 1) : ($i - 1)
                            }
                          }
                        
                          elseif ($round_match_count == 8) {
                            var.update $lmn {
                              value = 9 - $i
                            }
                          }
                        
                          elseif ($round_match_count == 32) {
                            conditional {
                              if ($i <= 16) {
                                var.update $lmn {
                                  value = $i + 16
                                }
                              }
                            
                              else {
                                var.update $lmn {
                                  value = $i - 16
                                }
                              }
                            }
                          }
                        
                          else {
                            var.update $lmn {
                              value = $i
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
    // Consolation rounds (full mode only, K >= 3)
    // ------------------------------------------------------------------
    conditional {
      if ($cons_enabled) {
        // Consolation pigtails: L(pigtail j) vs L(champ_r1 mirror match).
        // The winner takes the mirror loser's slot in cons_r1.
        foreach ($cons_pig_list) {
          each as $cp {
            array.push $descriptors {
              value = ```
                {
                  rc : "cons_pigtail"
                  rn : 0
                  rl : "Consolation Pigtail"
                  mn : $cp.j
                  sec: "consolation"
                  dor: 10000 + $cp.j
                  tt : "match_loser"
                  ts : null
                  trc: "pigtail"
                  tmn: $cp.j
                  bt : "match_loser"
                  bs : null
                  brc: "champ_r1"
                  bmn: $cp.mirror
                  wrc: "cons_r1"
                  wmn: $cp.cmn
                  wsl: $cp.csl
                  lrc: null
                  lmn: null
                  lsl: null
                  tw : null
                  bw : null
                }
                ```
            }
          }
        }
      
        // cons_r1: adjacent champ_r1 loser pairs, with pigtail-affected
        // slots replaced by the consolation pigtail winner. Winners feed
        // cons_r2 (for K=3, cons_r2 IS the Consolation Finals).
        var $cons_r1_label {
          value = ($k_rounds == 3) ? "Blood Round" : "Consolation R1"
        }
      
        for ($n_quarter) {
          each as $kidx {
            var $ck1 {
              value = $kidx + 1
            }
          
            var $cr1_tt {
              value = "match_loser"
            }
          
            var $cr1_trc {
              value = "champ_r1"
            }
          
            var $cr1_tmn {
              value = $r1_match_at_pos[(2 * $ck1) - 1]
            }
          
            var $cr1_bt {
              value = "match_loser"
            }
          
            var $cr1_brc {
              value = "champ_r1"
            }
          
            var $cr1_bmn {
              value = $r1_match_at_pos[2 * $ck1]
            }
          
            var $pig_top_key {
              value = $ck1 ~ "|top"
            }
          
            conditional {
              if ($cons_pig_slot_map|has:$pig_top_key) {
                var.update $cr1_tt {
                  value = "match_winner"
                }
              
                var.update $cr1_trc {
                  value = "cons_pigtail"
                }
              
                var.update $cr1_tmn {
                  value = $cons_pig_slot_map[$pig_top_key]
                }
              }
            }
          
            var $pig_bottom_key {
              value = $ck1 ~ "|bottom"
            }
          
            conditional {
              if ($cons_pig_slot_map|has:$pig_bottom_key) {
                var.update $cr1_bt {
                  value = "match_winner"
                }
              
                var.update $cr1_brc {
                  value = "cons_pigtail"
                }
              
                var.update $cr1_bmn {
                  value = $cons_pig_slot_map[$pig_bottom_key]
                }
              }
            }
          
            // K=3: cons_r1 doubles as the Blood Round; its losers -> place_7
            var $cr1_lrc {
              value = null
            }
          
            var $cr1_lmn {
              value = null
            }
          
            var $cr1_lsl {
              value = null
            }
          
            conditional {
              if ($k_rounds == 3) {
                var.update $cr1_lrc {
                  value = "place_7"
                }
              
                var.update $cr1_lmn {
                  value = 1
                }
              
                var.update $cr1_lsl {
                  value = ($ck1 == 1) ? "top" : "bottom"
                }
              }
            }
          
            array.push $descriptors {
              value = {
                rc : "cons_r1"
                rn : 1
                rl : $cons_r1_label
                mn : $ck1
                sec: "consolation"
                dor: 10100 + $ck1
                tt : $cr1_tt
                ts : null
                trc: $cr1_trc
                tmn: $cr1_tmn
                bt : $cr1_bt
                bs : null
                brc: $cr1_brc
                bmn: $cr1_bmn
                wrc: "cons_r2"
                wmn: $ck1
                wsl: "top"
                lrc: $cr1_lrc
                lmn: $cr1_lmn
                lsl: $cr1_lsl
                tw : null
                bw : null
              }
            }
          }
        }
      
        // K >= 4: staggered drop-in + pairing rounds for champ rounds 2..K-2
        conditional {
          if ($k_rounds >= 4) {
            var $drop_round_count {
              value = $k_rounds - 3
            }
          
            for ($drop_round_count) {
              each as $didx {
                var $ck {
                  value = $didx + 2
                }
              
                var $drop_code_num {
                  value = (2 * $ck) - 2
                }
              
                var $drop_code {
                  value = "cons_r" ~ $drop_code_num
                }
              
                var $drop_count {
                  value = ($n_size / (2|pow:$ck))|to_int
                }
              
                var $is_blood {
                  value = $ck == ($k_rounds - 2)
                }
              
                var $drop_label {
                  value = $is_blood ? "Blood Round" : ("Consolation R" ~ $drop_code_num)
                }
              
                var $prev_cons_code {
                  value = ($ck == 2) ? "cons_r1" : ("cons_r" ~ ((2 * $ck) - 3))
                }
              
                // drop-in winners feed the next pairing round, or the
                // Consolation Semis when this drop-in is the Blood Round
                var $drop_wrc {
                  value = $is_blood ? $semis_code : ("cons_r" ~ ((2 * $ck) - 1))
                }
              
                for ($drop_count) {
                  each as $jidx {
                    var $j {
                      value = $jidx + 1
                    }
                  
                    var $j_is_odd {
                      value = ($j|modulus:2) == 1
                    }
                  
                    // bottom source: champ round-ck loser, fully reversed,
                    // or pair-swapped on the Blood Round
                    var $drop_bmn {
                      value = 0
                    }
                  
                    conditional {
                      if ($is_blood) {
                        conditional {
                          if ($j_is_odd) {
                            var.update $drop_bmn {
                              value = $j + 1
                            }
                          }
                        
                          else {
                            var.update $drop_bmn {
                              value = $j - 1
                            }
                          }
                        }
                      }
                    
                      else {
                        var.update $drop_bmn {
                          value = ($drop_count - $j) + 1
                        }
                      }
                    }
                  
                    array.push $descriptors {
                      value = ```
                        {
                          rc : $drop_code
                          rn : $drop_code_num
                          rl : $drop_label
                          mn : $j
                          sec: "consolation"
                          dor: (10000 + ($drop_code_num * 100)) + $j
                          tt : "match_winner"
                          ts : null
                          trc: $prev_cons_code
                          tmn: $j
                          bt : "match_loser"
                          bs : null
                          brc: "champ_r" ~ $ck
                          bmn: $drop_bmn
                          wrc: $drop_wrc
                          wmn: (($j + 1) / 2)|floor
                          wsl: $j_is_odd ? "top" : "bottom"
                          lrc: null
                          lmn: null
                          lsl: null
                          tw : null
                          bw : null
                        }
                        ```
                    }
                  }
                }
              
                // pairing round after every drop-in except the Blood Round
                conditional {
                  if ($is_blood == false) {
                    var $pair_code_num {
                      value = (2 * $ck) - 1
                    }
                  
                    var $pair_count {
                      value = ($drop_count / 2)|to_int
                    }
                  
                    // pairing winners feed the next drop-in round (code 2*ck)
                    var $pair_wrc {
                      value = "cons_r" ~ (2 * $ck)
                    }
                  
                    for ($pair_count) {
                      each as $pidx {
                        var $pj2 {
                          value = $pidx + 1
                        }
                      
                        array.push $descriptors {
                          value = {
                            rc : "cons_r" ~ $pair_code_num
                            rn : $pair_code_num
                            rl : "Consolation R" ~ $pair_code_num
                            mn : $pj2
                            sec: "consolation"
                            dor: (10000 + ($pair_code_num * 100)) + $pj2
                            tt : "match_winner"
                            ts : null
                            trc: $drop_code
                            tmn: (2 * $pj2) - 1
                            bt : "match_winner"
                            bs : null
                            brc: $drop_code
                            bmn: 2 * $pj2
                            wrc: $pair_wrc
                            wmn: $pj2
                            wsl: "top"
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
          
            // Consolation Semis: adjacent Blood Round winner pairs.
            // Winners -> Consolation Finals; losers -> place_7.
            var $semis_rn {
              value = (2 * $k_rounds) - 5
            }
          
            for (2) {
              each as $sidx {
                var $si {
                  value = $sidx + 1
                }
              
                array.push $descriptors {
                  value = ```
                    {
                      rc : $semis_code
                      rn : $semis_rn
                      rl : "Consolation Semis"
                      mn : $si
                      sec: "consolation"
                      dor: (10000 + ($semis_rn * 100)) + $si
                      tt : "match_winner"
                      ts : null
                      trc: $blood_code
                      tmn: (2 * $si) - 1
                      bt : "match_winner"
                      bs : null
                      brc: $blood_code
                      bmn: 2 * $si
                      wrc: $cons_finals_code
                      wmn: $si
                      wsl: "top"
                      lrc: "place_7"
                      lmn: 1
                      lsl: ($si == 1) ? "top" : "bottom"
                      tw : null
                      bw : null
                    }
                    ```
                }
              }
            }
          }
        }
      
        // Consolation Finals (the 581/582 matches): winners of the feeding
        // round (cons_r1 for K=3, Consolation Semis for K>=4) vs champ SF
        // losers, cross-half. Winners -> place_3; losers -> place_5.
        var $cf_feed_code {
          value = ($k_rounds == 3) ? "cons_r1" : $semis_code
        }
      
        for (2) {
          each as $fidx {
            var $fi {
              value = $fidx + 1
            }
          
            array.push $descriptors {
              value = ```
                {
                  rc : $cons_finals_code
                  rn : $cons_finals_rn
                  rl : "Consolation Finals"
                  mn : $fi
                  sec: "consolation"
                  dor: (10000 + ($cons_finals_rn * 100)) + $fi
                  tt : "match_winner"
                  ts : null
                  trc: $cf_feed_code
                  tmn: $fi
                  bt : "match_loser"
                  bs : null
                  brc: "champ_r" ~ $k_minus_1
                  bmn: 3 - $fi
                  wrc: "place_3"
                  wmn: 1
                  wsl: ($fi == 1) ? "top" : "bottom"
                  lrc: "place_5"
                  lmn: 1
                  lsl: ($fi == 1) ? "top" : "bottom"
                  tw : null
                  bw : null
                }
                ```
            }
          }
        }
      }
    }
  
    // ------------------------------------------------------------------
    // Placement matches
    // ------------------------------------------------------------------
    var $place3_tt {
      value = "match_loser"
    }
  
    var $place3_trc {
      value = "champ_r" ~ $k_minus_1
    }
  
    // Full consolation: place_3 is W(cons finals) vs W(cons finals);
    // otherwise it is the champ SF losers.
    conditional {
      if ($cons_enabled) {
        var.update $place3_tt {
          value = "match_winner"
        }
      
        var.update $place3_trc {
          value = $cons_finals_code
        }
      }
    }
  
    array.push $descriptors {
      value = {
        rc : "place_3"
        rn : 1
        rl : "3rd Place"
        mn : 1
        sec: "placement"
        dor: 5001
        tt : $place3_tt
        ts : null
        trc: $place3_trc
        tmn: 1
        bt : $place3_tt
        bs : null
        brc: $place3_trc
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
        // place_5 = losers of the Consolation Finals
        array.push $descriptors {
          value = {
            rc : "place_5"
            rn : 2
            rl : "5th Place"
            mn : 1
            sec: "placement"
            dor: 5002
            tt : "match_loser"
            ts : null
            trc: $cons_finals_code
            tmn: 1
            bt : "match_loser"
            bs : null
            brc: $cons_finals_code
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
      
        // place_7 = losers of the two matches feeding the Consolation Finals'
        // top slots (Consolation Semis for K>=4, cons_r1 for K=3)
        var $place7_feed_code {
          value = ($k_rounds == 3) ? "cons_r1" : $semis_code
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
            trc: $place7_feed_code
            tmn: 1
            bt : "match_loser"
            bs : null
            brc: $place7_feed_code
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
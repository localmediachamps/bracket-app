// Staged probe replicating bracket_generate's constructs for field_4.
// Input stage N runs stages 1..N and returns diagnostics. Used to pinpoint
// the exact construct that fails at runtime (500 "Invalid syntax").
function probe_generate {
  input {
    int stage
    int weight_class_id
    int tournament_id
  }

  stack {
    var $out {
      value = {ok: true, stage: $input.stage, failed_at: null}
    }
  
    // STAGE 1: seed loading + K computation + basic vars
    db.query wrestler {
      where = $db.wrestler.weight_class_id == $input.weight_class_id
      sort = {seed: "asc"}
      return = {type: "list"}
      output = ["id", "seed"]
    } as $wrestlers
  
    var $competitor_count {
      value = $wrestlers|count
    }
  
    var $n_size {
      value = 4
    }
  
    var $k_rounds {
      value = 2
    }
  
    var $cons_enabled {
      value = false
    }
  
    var $n_quarter {
      value = ($n_size / 4)|to_int
    }
  
    var $n_half {
      value = ($n_size / 2)|to_int
    }
  
    var.update $out {
      value = $out
        |set:"competitor_count":$competitor_count
    }
  
    // STAGE 2: R-cycle maps (for loop, modulus, |set: with dynamic keys)
    conditional {
      if ($input.stage >= 2) {
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
                conditional {
                  if ((($ri|modulus:2) == 1)) {
                    var.update $rpos {
                      value = ($ri + 1)
                    }
                  }
                
                  else {
                    var.update $rpos {
                      value = ($ri - 1)
                    }
                  }
                }
              }
            }
          
            var.update $r1_match_at_pos {
              value = $r1_match_at_pos|set:$rpos:$ri
            }
          }
        }
      
        var.update $out {
          value = $out|set:"r1_map":$r1_match_at_pos
        }
      }
    }
  
    // STAGE 3: positions while loop
    conditional {
      if ($input.stage >= 3) {
        var $c_firsts {
          value = [1, 2]
        }
      
        var $c_size {
          value = 4
        }
      
        while ($c_size < $n_size) {
          each {
            var $next_c {
              value = []
            }
          
            var $cidx {
              value = 0
            }
          
            foreach ($c_firsts) {
              each as $cx {
                var.update $cidx {
                  value = $cidx + 1
                }
              
                conditional {
                  if (($cidx|modulus:2) == 1) {
                    array.push $next_c {
                      value = $cx
                    }
                  
                    array.push $next_c {
                      value = ($c_size + 1) - $cx
                    }
                  }
                
                  else {
                    array.push $next_c {
                      value = ($c_size + 1) - $cx
                    }
                  
                    array.push $next_c {
                      value = $cx
                    }
                  }
                }
              }
            }
          
            var.update $c_firsts {
              value = $next_c
            }
          
            var.update $c_size {
              value = $c_size * 2
            }
          }
        }
      
        var.update $out {
          value = $out|set:"c_firsts":$c_firsts
        }
      }
    }
  
    // STAGE 4: positions foreach + computed-index hoisted access
    conditional {
      if ($input.stage >= 4) {
        var $c_firsts4 {
          value = [1, 2]
        }
      
        var $positions {
          value = []
        }
      
        foreach ($c_firsts4) {
          each as $fx {
            array.push $positions {
              value = $fx
            }
          
            array.push $positions {
              value = ($n_size + 1) - $fx
            }
          }
        }
      
        var $i {
          value = 1
        }
      
        var $top_pos_idx {
          value = (2 * $i) - 2
        }
      
        var $bottom_pos_idx {
          value = (2 * $i) - 1
        }
      
        var $top_seed_pos {
          value = $positions[$top_pos_idx]
        }
      
        var $bottom_seed_pos {
          value = $positions[$bottom_pos_idx]
        }
      
        var.update $out {
          value = $out
            |set:"positions":$positions
            |set:"top_seed":$top_seed_pos
            |set:"bottom_seed":$bottom_seed_pos
        }
      }
    }
  
    // STAGE 5: descriptor push (plain object literal)
    conditional {
      if ($input.stage >= 5) {
        var $descriptors {
          value = []
        }
      
        array.push $descriptors {
          value = {
            rc : "champ_r1"
            rn : 1
            mn : 1
            sec: "championship"
            dor: 101
            tt : "seed"
            ts : 1
            tw : null
          }
        }
      
        var.update $out {
          value = $out
            |set:"descriptor_count":($descriptors|count)
        }
      }
    }
  
    // STAGE 6: descriptor push (backtick literal)
    conditional {
      if ($input.stage >= 6) {
        var $descriptors2 {
          value = []
        }
      
        array.push $descriptors2 {
          value = ```
            {
              rc : "cons_pigtail"
              rn : 0
              mn : 1
              tt : "match_loser"
            }
            ```
        }
      
        var.update $out {
          value = $out
            |set:"descriptor2_count":($descriptors2|count)
        }
      }
    }
  
    // STAGE 7: db.add bracket_match from a descriptor
    conditional {
      if ($input.stage >= 7) {
        try_catch {
          try {
            db.add bracket_match {
              data = {
                tournament_id         : $input.tournament_id
                weight_class_id       : $input.weight_class_id
                round_code            : "champ_r1"
                round_number          : 1
                round_label           : "Semifinals"
                match_number          : 1
                bracket_section       : "championship"
                top_source_type       : "seed"
                top_source_seed       : 1
                bottom_source_type    : "seed"
                bottom_source_seed    : 4
                actual_top_wrestler_id: null
                match_status          : "pending"
                version               : 1
                display_order         : 101
              }
            } as $probe_match
          
            var.update $out {
              value = $out
                |set:"probe_match_id":$probe_match.id
            }
          
            // clean up the probe match
            db.del bracket_match {
              field_name = "id"
              field_value = $probe_match.id
            }
          }
        
          catch {
            var.update $out {
              value = $out
                |set:"stage7_note":"db.add threw (duplicate or constraint)"
            }
          }
        }
      }
    }
  
    // STAGE 8: dynamic map read with |has: + $map[$key]
    conditional {
      if ($input.stage >= 8) {
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
      
        var $probe_seed {
          value = 1
        }
      
        var $has_it {
          value = $seed_map|has:$probe_seed
        }
      
        var $wrestler_id {
          value = $seed_map[$probe_seed]
        }
      
        var.update $out {
          value = $out
            |set:"has_seed":$has_it
            |set:"wrestler_id":$wrestler_id
        }
      }
    }
  
    // STAGE 9: function.run bracket_self_check
    conditional {
      if ($input.stage >= 9) {
        function.run bracket_self_check {
          input = {weight_class_id: $input.weight_class_id}
        } as $check
      
        var.update $out {
          value = $out
            |set:"self_check_valid":$check.valid
        }
      }
    }
  
    // STAGE 10: |set: with a dynamic key + db.patch with computed payload
    conditional {
      if ($input.stage >= 10) {
        var $adv_field {
          value = "actual_top_wrestler_id"
        }
      
        var $adv_payload {
          value = {}|set:$adv_field:123
        }
      
        var $probe_match2 {
          value = null
        }
      
        try_catch {
          try {
            db.add bracket_match {
              data = {
                tournament_id  : $input.tournament_id
                weight_class_id: $input.weight_class_id
                round_code     : "probe_test"
                round_number   : 1
                match_number   : 1
                bracket_section: "championship"
                match_status   : "pending"
                version        : 1
              }
            } as $pm2
          
            var.update $probe_match2 {
              value = $pm2
            }
          }
        
          catch {
            db.query bracket_match {
              where = $db.bracket_match.weight_class_id == $input.weight_class_id && $db.bracket_match.round_code == "probe_test" && $db.bracket_match.match_number == 1
              return = {type: "single"}
            } as $pm2b
          
            var.update $probe_match2 {
              value = $pm2b
            }
          }
        }
      
        db.patch bracket_match {
          field_name = "id"
          field_value = $probe_match2.id
          data = $adv_payload
        } as $probe_patched
      
        var.update $out {
          value = $out
            |set:"dynamic_payload":$adv_payload
            |set:"patched_top_id":$probe_patched.actual_top_wrestler_id
        }
      
        db.del bracket_match {
          field_name = "id"
          field_value = $probe_match2.id
        }
      }
    }
  
    // STAGE 11: db.edit with explicit null values in the data literal (wiring-pass form)
    conditional {
      if ($input.stage >= 11) {
        var $probe_match3 {
          value = null
        }
      
        try_catch {
          try {
            db.add bracket_match {
              data = {
                tournament_id  : $input.tournament_id
                weight_class_id: $input.weight_class_id
                round_code     : "probe_test"
                round_number   : 1
                match_number   : 2
                bracket_section: "championship"
                match_status   : "pending"
                version        : 1
              }
            } as $pm3
          
            var.update $probe_match3 {
              value = $pm3
            }
          }
        
          catch {
            db.query bracket_match {
              where = $db.bracket_match.weight_class_id == $input.weight_class_id && $db.bracket_match.round_code == "probe_test" && $db.bracket_match.match_number == 2
              return = {type: "single"}
            } as $pm3b
          
            var.update $probe_match3 {
              value = $pm3b
            }
          }
        }
      
        var $null_src {
          value = null
        }
      
        db.edit bracket_match {
          field_name = "id"
          field_value = $probe_match3.id
          data = {
            top_source_match_id        : $null_src
            bottom_source_match_id     : $null_src
            winner_advances_to_match_id: $null_src
            loser_drops_to_match_id    : $null_src
          }
        } as $probe_wired
      
        var.update $out {
          value = $out|set:"wired_ok":true
        }
      
        db.del bracket_match {
          field_name = "id"
          field_value = $probe_match3.id
        }
      }
    }
  
    // STAGE 12: dynamic key read for a MISSING key (id_map miss)
    conditional {
      if ($input.stage >= 12) {
        var $small_map {
          value = {}|set:"a":1
        }
      
        var $missing {
          value = null
        }
      
        try_catch {
          try {
            var.update $missing {
              value = $small_map.zzz
            }
          }
        
          catch {
            var.update $out {
              value = $out
                |set:"missing_key_error":$error.message
            }
          }
        }
      
        var.update $out {
          value = $out
            |set:"missing_key_result":$missing
        }
      }
    }
  
    // STAGE 13: pipe-containing map keys (the generator's id_map key form "champ_r1|1")
    conditional {
      if ($input.stage >= 13) {
        var $pipe_key {
          value = "champ_r1" ~ "|" ~ "1"
        }
      
        var $pipe_map {
          value = {}
        }
      
        var.update $pipe_map {
          value = $pipe_map|set:$pipe_key:42
        }
      
        var $pipe_read {
          value = $pipe_map[$pipe_key]
        }
      
        var.update $out {
          value = $out
            |set:"pipe_key":$pipe_key
            |set:"pipe_read":$pipe_read
        }
      }
    }
  }


    // STAGE 14: |get: with a VARIABLE key vs |has: vs bracket read
    conditional {
      if ($input.stage >= 14) {
        var $gk {
          value = "alpha"
        }

        var $gmap {
          value = {}
        }

        var.update $gmap {
          value = $gmap|set:$gk:5
        }

        var $via_get {
          value = $gmap|get:$gk:0
        }

        var $via_has {
          value = $gmap|has:$gk
        }

        var $via_bracket {
          value = $gmap[$gk]
        }

        var $via_get_missing {
          value = $gmap|get:"missing":0
        }

        var.update $out {
          value = $out
            |set:"via_get":$via_get
            |set:"via_has":$via_has
            |set:"via_bracket":$via_bracket
            |set:"via_get_missing":$via_get_missing
        }
      }
    }

  response = $out
}
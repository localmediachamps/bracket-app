// Re-scores bracket entries for a tournament and recomputes leaderboard ranks
// (ARCHITECTURE.md section 5). Scopes to optional entry_ids when provided,
// otherwise every draft|submitted|locked entry.
// Ranking: submitted|locked entries first, ordered by the scoring_config tiebreakers
// (default: total_points desc, champions_correct desc, finalists_correct desc,
// earliest submission); drafts rank after, ordered by total_points.
// prev_rank snapshots the old rank before rank is written.
// Also triggers the pick'em rescore and clears tournament.needs_rescore.
// Full idempotent rescore and re-rank of a tournament's bracket entries, plus pick'em rescore
function rescore_tournament {
  input {
    // Tournament to rescore
    int tournament_id
  
    // Optional subset of user_bracket ids to rescore; ranking still covers the whole tournament
    int[] entry_ids?
  }

  stack {
    db.get tournament {
      field_name = "id"
      field_value = $input.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    // Resolve scoring config (for tiebreakers), falling back to defaults
    var $scoring_config {
      value = $tournament.scoring_config
    }
  
    conditional {
      if ($scoring_config == null) {
        function.run get_default_scoring_config as $default_config
        var.update $scoring_config {
          value = $default_config
        }
      }
    }
  
    var $tiebreakers {
      value = $scoring_config|get:"tiebreakers":null
    }
  
    conditional {
      if ($tiebreakers == null || ($tiebreakers|count) == 0) {
        var.update $tiebreakers {
          value = [
            "total_points"
            "champions_correct"
            "finalists_correct"
            "earliest_submission"
          ]
        }
      }
    }
  
    // Score every entry in scope
    db.query user_bracket {
      where = $db.user_bracket.tournament_id == $input.tournament_id
      return = {type: "list"}
    } as $entries
  
    var $scored_count {
      value = 0
    }
  
    foreach ($entries) {
      each as $entry {
        var $in_scope {
          value = false
        }
      
        conditional {
          if ($entry.status == "submitted" || $entry.status == "locked" || $entry.status == "draft") {
            conditional {
              if ($input.entry_ids == null || ($input.entry_ids|count) == 0) {
                var.update $in_scope {
                  value = true
                }
              }
            
              elseif ($input.entry_ids|some:$$ == $entry.id) {
                var.update $in_scope {
                  value = true
                }
              }
            }
          }
        }
      
        conditional {
          if ($in_scope) {
            function.run score_entry {
              input = {user_bracket_id: $entry.id}
            } as $score_result
          
            math.add $scored_count {
              value = 1
            }
          }
        }
      }
    }
  
    // Reload fresh totals for ranking
    db.query user_bracket {
      where = $db.user_bracket.tournament_id == $input.tournament_id
      return = {type: "list"}
    } as $fresh_entries
  
    var $rank_pool {
      value = []
    }
  
    var $draft_pool {
      value = []
    }
  
    foreach ($fresh_entries) {
      each as $fe {
        conditional {
          if ($fe.status == "submitted" || $fe.status == "locked") {
            array.push $rank_pool {
              value = $fe
            }
          }
        
          else {
            array.push $draft_pool {
              value = $fe
            }
          }
        }
      }
    }
  
    // Snapshot the competitive (submitted|locked) pool size before the
    // while-loop below consumes $rank_pool - this is the master leaderboard's
    // "entrants" denominator further down (drafts never count toward it).
    var $competitive_count {
      value = $rank_pool|count
    }

    // Order the submitted|locked pool by walking the tiebreaker config.
    // Repeatedly takes the best remaining entry (deterministic; id asc is the final tiebreak).
    var $ranked {
      value = []
    }

    while (($rank_pool|count) > 0) {
      each {
        var $best {
          value = $rank_pool|first
        }
      
        foreach ($rank_pool) {
          each as $cand {
            var $cand_better {
              value = false
            }
          
            var $decided {
              value = false
            }
          
            var $cand_total {
              value = $cand.total_points|first_notnull:0
            }
          
            var $best_total {
              value = $best.total_points|first_notnull:0
            }
          
            var $cand_champs {
              value = $cand.champions_correct|first_notnull:0
            }
          
            var $best_champs {
              value = $best.champions_correct|first_notnull:0
            }
          
            var $cand_finalists {
              value = $cand.finalists_correct|first_notnull:0
            }
          
            var $best_finalists {
              value = $best.finalists_correct|first_notnull:0
            }
          
            foreach ($tiebreakers) {
              each as $tb {
                conditional {
                  if ($decided == false) {
                    conditional {
                      if ($tb == "total_points") {
                        conditional {
                          if ($cand_total > $best_total) {
                            var.update $cand_better {
                              value = true
                            }
                          
                            var.update $decided {
                              value = true
                            }
                          }
                        
                          elseif ($cand_total < $best_total) {
                            var.update $decided {
                              value = true
                            }
                          }
                        }
                      }
                    
                      elseif ($tb == "champions_correct") {
                        conditional {
                          if ($cand_champs > $best_champs) {
                            var.update $cand_better {
                              value = true
                            }
                          
                            var.update $decided {
                              value = true
                            }
                          }
                        
                          elseif ($cand_champs < $best_champs) {
                            var.update $decided {
                              value = true
                            }
                          }
                        }
                      }
                    
                      elseif ($tb == "finalists_correct") {
                        conditional {
                          if ($cand_finalists > $best_finalists) {
                            var.update $cand_better {
                              value = true
                            }
                          
                            var.update $decided {
                              value = true
                            }
                          }
                        
                          elseif ($cand_finalists < $best_finalists) {
                            var.update $decided {
                              value = true
                            }
                          }
                        }
                      }
                    
                      elseif ($tb == "earliest_submission") {
                        conditional {
                          if ($cand.submitted_at == null && $best.submitted_at != null) {
                            var.update $decided {
                              value = true
                            }
                          }
                        
                          elseif ($cand.submitted_at != null && $best.submitted_at == null) {
                            var.update $cand_better {
                              value = true
                            }
                          
                            var.update $decided {
                              value = true
                            }
                          }
                        
                          elseif ($cand.submitted_at != null && $best.submitted_at != null) {
                            conditional {
                              if ($cand.submitted_at < $best.submitted_at) {
                                var.update $cand_better {
                                  value = true
                                }
                              
                                var.update $decided {
                                  value = true
                                }
                              }
                            
                              elseif ($cand.submitted_at > $best.submitted_at) {
                                var.update $decided {
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
          
            // deterministic final tiebreak: lower id ranks first
            conditional {
              if ($decided == false && $cand.id < $best.id) {
                var.update $cand_better {
                  value = true
                }
              }
            }
          
            conditional {
              if ($cand_better) {
                var.update $best {
                  value = $cand
                }
              }
            }
          }
        }
      
        array.push $ranked {
          value = $best
        }
      
        var.update $rank_pool {
          value = $rank_pool|remove:$best
        }
      }
    }
  
    // Drafts rank after, by total_points desc (id asc as final tiebreak)
    var $ranked_drafts {
      value = []
    }
  
    while (($draft_pool|count) > 0) {
      each {
        var $best_draft {
          value = $draft_pool|first
        }
      
        foreach ($draft_pool) {
          each as $dcand {
            var $dcand_total {
              value = $dcand.total_points|first_notnull:0
            }
          
            var $dbest_total {
              value = $best_draft.total_points|first_notnull:0
            }
          
            conditional {
              if ($dcand_total > $dbest_total || ($dcand_total == $dbest_total && $dcand.id < $best_draft.id)) {
                var.update $best_draft {
                  value = $dcand
                }
              }
            }
          }
        }
      
        array.push $ranked_drafts {
          value = $best_draft
        }
      
        var.update $draft_pool {
          value = $draft_pool|remove:$best_draft
        }
      }
    }
  
    array.merge $ranked {
      value = $ranked_drafts
    }
  
    // Write ranks; prev_rank snapshots the old rank
    var $ranked_count {
      value = $ranked|count
    }
  
    for ($ranked_count) {
      each as $ridx {
        var $rentry {
          value = $ranked[$ridx]
        }
      
        var $new_rank {
          value = $ridx + 1
        }
      
        db.edit user_bracket {
          field_name = "id"
          field_value = $rentry.id
          data = {
            prev_rank : $rentry.rank
            rank      : $new_rank
            updated_at: "now"
          }
        } as $ranked_entry
      }
    }

    // Master leaderboard: percentile-based points for genuinely competitive
    // (submitted|locked) entries only - drafts never earn a row here. Uses
    // the same $ranked ordering this rescore just computed (submitted|locked
    // entries always sort before drafts), not a fresh query, so it reflects
    // exactly what was just ranked above.
    function.run get_default_platform_leaderboard_config {
      input = {}
    } as $platform_config

    conditional {
      if ($competitive_count > 0) {
        for ($competitive_count) {
          each as $pidx {
            var $pentry {
              value = $ranked[$pidx]
            }

            var $prank {
              value = $pidx + 1
            }

            var $ppercentile {
              value = ($competitive_count - $prank + 1) / $competitive_count
            }

            var $ppoints {
              value = ($ppercentile|pow:$platform_config.percentile.curve_exponent) * $platform_config.percentile.scale
            }

            db.query platform_leaderboard_entry {
              where = $db.platform_leaderboard_entry.user_id == $pentry.user_id && $db.platform_leaderboard_entry.tournament_id == $input.tournament_id && $db.platform_leaderboard_entry.source_type == "bracket"
              return = {type: "single"}
            } as $existing_ple

            conditional {
              if ($existing_ple != null) {
                db.edit platform_leaderboard_entry {
                  field_name = "id"
                  field_value = $existing_ple.id
                  data = {
                    rank_in_tournament: $prank
                    entrants          : $competitive_count
                    percentile        : $ppercentile
                    points_awarded    : $ppoints
                    scoring_path      : "percentile"
                    year              : $tournament.year
                  }
                } as $updated_ple
              }
              else {
                db.add platform_leaderboard_entry {
                  data = {
                    created_at        : now
                    user_id           : $pentry.user_id
                    tournament_id     : $input.tournament_id
                    source_type       : "bracket"
                    scoring_path      : "percentile"
                    rank_in_tournament: $prank
                    entrants          : $competitive_count
                    percentile        : $ppercentile
                    points_awarded    : $ppoints
                    year              : $tournament.year
                  }
                } as $new_ple
              }
            }
          }
        }
      }
    }

    // Clear the dirty flag
    db.edit tournament {
      field_name = "id"
      field_value = $input.tournament_id
      data = {needs_rescore: false}
    } as $updated_tournament
  
    // Pick'em leaderboard rides along
    function.run rescore_pickem {
      input = {tournament_id: $input.tournament_id}
    } as $pickem_rescore
  }

  response = {
    entries_scored: $scored_count
    entries_ranked: $ranked_count
  }
  guid = "esVL9_AUBYlqGcqQW1T56HjLuxg"
}
// Ranked leaderboard of a fantasy group's active members (ARCHITECTURE.md section 6:
// GET /groups/{id}/leaderboard?mode=).
// Bracket mode ranks user_bracket entries; pickem mode ranks pickem_entry rows
// (pickem has no champions/correct counts, those fields are 0/null).
// Sort: total_points desc, champions_correct desc, submitted_at asc.
// Paginated response: {items, total, page, per}.
// Ranked entries of active group members for the group's tournament
function group_leaderboard {
  input {
    // Fantasy group id
    int group_id
  
    // bracket or pickem
    text mode?=bracket filters=trim|lower
  
    // 1-based page number
    int page?=1 filters=min:1
  
    // Page size (max 100)
    int per?=25 filters=min:1|max:100
  }

  stack {
    precondition ($input.mode == "bracket" || $input.mode == "pickem") {
      error_type = "inputerror"
      error = "mode must be bracket or pickem"
    }
  
    db.get fantasy_group {
      field_name = "id"
      field_value = $input.group_id
    } as $group
  
    precondition ($group != null) {
      error_type = "notfound"
      error = "Group not found"
    }
  
    // Active members only
    db.query group_membership {
      where = $db.group_membership.group_id == $input.group_id && $db.group_membership.status == "active"
      return = {type: "list"}
    } as $members
  
    // Build one leaderboard row per member that has an entry in this tournament
    var $rows {
      value = []
    }
  
    foreach ($members) {
      each as $member {
        db.get user {
          field_name = "id"
          field_value = $member.user_id
        } as $member_user
      
        // The member's entry for the group's tournament (mode dependent)
        var $entry {
          value = null
        }
      
        conditional {
          if ($input.mode == "bracket") {
            db.query user_bracket {
              where = $db.user_bracket.tournament_id == $group.tournament_id && $db.user_bracket.user_id == $member.user_id
              return = {type: "single"}
            } as $bracket_entry
          
            var.update $entry {
              value = $bracket_entry
            }
          }
        
          else {
            db.query pickem_entry {
              where = $db.pickem_entry.tournament_id == $group.tournament_id && $db.pickem_entry.user_id == $member.user_id
              return = {type: "single"}
            } as $pickem_entry_row
          
            var.update $entry {
              value = $pickem_entry_row
            }
          }
        }
      
        conditional {
          if ($entry != null && $member_user != null) {
            var $total_points {
              value = 0
            }
          
            conditional {
              if ($entry.total_points != null) {
                var.update $total_points {
                  value = $entry.total_points
                }
              }
            }
          
            // Bracket-only aggregates; pickem rows keep 0/null
            var $champions_correct {
              value = 0
            }
          
            var $correct_pick_count {
              value = 0
            }
          
            var $scored_pick_count {
              value = 0
            }
          
            var $possible_points {
              value = null
            }
          
            conditional {
              if ($input.mode == "bracket") {
                conditional {
                  if ($entry.champions_correct != null) {
                    var.update $champions_correct {
                      value = $entry.champions_correct
                    }
                  }
                }
              
                conditional {
                  if ($entry.correct_pick_count != null) {
                    var.update $correct_pick_count {
                      value = $entry.correct_pick_count
                    }
                  }
                }
              
                conditional {
                  if ($entry.scored_pick_count != null) {
                    var.update $scored_pick_count {
                      value = $entry.scored_pick_count
                    }
                  }
                }
              
                var.update $possible_points {
                  value = $entry.possible_points
                }
              }
            }
          
            // accuracy = correct / scored, 0-1 rounded to 3 decimals
            var $accuracy {
              value = 0
            }
          
            conditional {
              if ($scored_pick_count > 0) {
                var $accuracy_raw {
                  value = ($correct_pick_count * 1000) / $scored_pick_count
                }
              
                var.update $accuracy {
                  value = ($accuracy_raw|round) / 1000
                }
              }
            }
          
            // Sortable submission key: earlier submission = smaller = better.
            // Null (never submitted) sorts last.
            var $sub_key {
              value = 9999999999999
            }
          
            conditional {
              if ($entry.submitted_at != null) {
                var.update $sub_key {
                  value = $entry.submitted_at
                }
              }
            }
          
            array.push $rows {
              value = {
                entry_id          : $entry.id
                user_id           : $member.user_id
                user              : {
                  id          : $member_user.id
                  username    : $member_user.username
                  display_name: $member_user.display_name
                  avatar_url  : $member_user.avatar_url
                }
                total_points      : $total_points
                possible_points   : $possible_points
                correct_pick_count: $correct_pick_count
                scored_pick_count : $scored_pick_count
                accuracy          : $accuracy
                champions_correct : $champions_correct
                status            : $entry.status
                submitted_at      : $entry.submitted_at
                prev_rank         : $entry.prev_rank
                sub_key           : $sub_key
              }
            }
          }
        }
      }
    }
  
    // Assign ranks with a strict pairwise comparator (total_points desc,
    // champions_correct desc, submitted_at asc, entry_id asc as final tiebreak
    // so ranks are always a clean 1..n permutation).
    var $ranked {
      value = []
    }
  
    foreach ($rows) {
      each as $r {
        var $rank {
          value = 1
        }
      
        foreach ($rows) {
          each as $o {
            conditional {
              if ($o.entry_id != $r.entry_id) {
                var $beats {
                  value = false
                }
              
                conditional {
                  if ($o.total_points > $r.total_points) {
                    var.update $beats {
                      value = true
                    }
                  }
                
                  elseif ($o.total_points == $r.total_points && $o.champions_correct > $r.champions_correct) {
                    var.update $beats {
                      value = true
                    }
                  }
                
                  elseif ($o.total_points == $r.total_points && $o.champions_correct == $r.champions_correct && $o.sub_key < $r.sub_key) {
                    var.update $beats {
                      value = true
                    }
                  }
                
                  elseif ($o.total_points == $r.total_points && $o.champions_correct == $r.champions_correct && $o.sub_key == $r.sub_key && $o.entry_id < $r.entry_id) {
                    var.update $beats {
                      value = true
                    }
                  }
                }
              
                conditional {
                  if ($beats) {
                    math.add $rank {
                      value = 1
                    }
                  }
                }
              }
            }
          }
        }
      
        array.push $ranked {
          value = $r|set:"rank":$rank
        }
      }
    }
  
    // Emit rows in rank order; rank_change = prev_rank - rank (0 when no prev_rank)
    var $ordered {
      value = []
    }
  
    for ($ranked|count) {
      each as $i {
        var $target_rank {
          value = $i + 1
        }
      
        foreach ($ranked) {
          each as $row {
            conditional {
              if ($row.rank == $target_rank) {
                var $rank_change {
                  value = 0
                }
              
                conditional {
                  if ($row.prev_rank != null) {
                    var.update $rank_change {
                      value = $row.prev_rank - $row.rank
                    }
                  }
                }
              
                array.push $ordered {
                  value = {
                    rank              : $row.rank
                    rank_change       : $rank_change
                    user              : $row.user
                    total_points      : $row.total_points
                    possible_points   : $row.possible_points
                    correct_pick_count: $row.correct_pick_count
                    scored_pick_count : $row.scored_pick_count
                    accuracy          : $row.accuracy
                    champions_correct : $row.champions_correct
                    status            : $row.status
                    submitted_at      : $row.submitted_at
                  }
                }
              }
            }
          }
        }
      }
    }
  
    // Paginate
    var $total {
      value = $ordered|count
    }
  
    var $offset {
      value = ($input.page - 1) * $input.per
    }
  
    var $items {
      value = $ordered|slice:$offset:$input.per
    }
  }

  response = {
    items: $items
    total: $total
    page : $input.page
    per  : $input.per
  }
}
// Tournament leaderboard. mode=bracket ranks user_bracket rows; mode=pickem ranks
// pickem_entry rows. Only ranked rows (rank not null), ordered by rank ascending.
// rank_change = prev_rank - rank (positive = moved up). accuracy = correct/scored.
query "tournaments/{id}/leaderboard" verb=GET {
  api_group = "brackets"

  input {
    // Tournament id
    int id
  
    // bracket or pickem
    text? mode?=bracket filters=trim|lower
  
    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    precondition ($input.mode == "bracket" || $input.mode == "pickem") {
      error_type = "inputerror"
      error = "mode must be bracket or pickem."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    var $items {
      value = []
    }
  
    var $total {
      value = 0
    }
  
    conditional {
      if ($input.mode == "bracket") {
        db.query user_bracket {
          where = $db.user_bracket.tournament_id == $input.id && $db.user_bracket.rank != null
          sort = {user_bracket.rank: "asc"}
          return = {
            type  : "list"
            paging: {page: $input.page, per_page: $input.per, totals: true}
          }
        } as $page
      
        var.update $total {
          value = $page.itemsTotal
        }
      
        foreach ($page.items) {
          each as $row {
            db.get user {
              field_name = "id"
              field_value = $row.user_id
              output = ["id", "username", "display_name", "avatar_url"]
            } as $row_user
          
            var $rank_change {
              value = null
            }
          
            conditional {
              if (($row.prev_rank != null && $row.rank != null)) {
                var.update $rank_change {
                  value = ($row.prev_rank - $row.rank)
                }
              }
            
              else {
                var.update $rank_change {
                  value = null
                }
              }
            }
          
            var $accuracy {
              value = null
            }
          
            conditional {
              if ($row.scored_pick_count > 0) {
                var.update $accuracy {
                  value = (($row.correct_pick_count / $row.scored_pick_count)|round:3)
                }
              }
            }
          
            array.push $items {
              value = $row
                |set:"user":$row_user
                |set:"rank_change":$rank_change
                |set:"accuracy":$accuracy
            }
          }
        }
      }
    
      else {
        db.query pickem_entry {
          where = $db.pickem_entry.tournament_id == $input.id && $db.pickem_entry.rank != null
          sort = {pickem_entry.rank: "asc"}
          return = {
            type  : "list"
            paging: {page: $input.page, per_page: $input.per, totals: true}
          }
        } as $pickem_page
      
        var.update $total {
          value = $pickem_page.itemsTotal
        }
      
        foreach ($pickem_page.items) {
          each as $prow {
            db.get user {
              field_name = "id"
              field_value = $prow.user_id
              output = ["id", "username", "display_name", "avatar_url"]
            } as $prow_user
          
            var $prank_change {
              value = null
            }
          
            conditional {
              if (($prow.prev_rank != null && $prow.rank != null)) {
                var.update $prank_change {
                  value = ($prow.prev_rank - $prow.rank)
                }
              }
            
              else {
                var.update $prank_change {
                  value = null
                }
              }
            }
          
            array.push $items {
              value = $prow
                |set:"user":$prow_user
                |set:"rank_change":$prank_change
                |set:"accuracy":null
            }
          }
        }
      }
    }
  }

  response = {
    items: $items
    total: $total
    page : $input.page
    per  : $input.per
  }
}
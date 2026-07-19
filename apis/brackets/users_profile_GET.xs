// Public mini-profile: user card, aggregate stats (entries, best rank, average
// accuracy across scored picks), and the 5 most recent ranked finishes.
query "users/{id}/profile" verb=GET {
  api_group = "brackets"

  input {
    // User id
    int id
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $input.id
    } as $user
  
    precondition ($user != null) {
      error_type = "notfound"
      error = "User not found."
    }
  
    var $profile {
      value = {
        id             : $user.id
        username       : $user.username
        display_name   : $user.display_name
        avatar_url     : $user.avatar_url
        bio            : $user.bio
        favorite_school: $user.favorite_school
        created_at     : $user.created_at
      }
    }
  
    // Aggregate stats across all of the user's bracket entries
    db.query user_bracket {
      where = $db.user_bracket.user_id == $input.id
      return = {type: "list"}
    } as $entries
  
    var $entries_count {
      value = $entries|count
    }
  
    var $total_correct {
      value = 0
    }
  
    var $total_scored {
      value = 0
    }
  
    foreach ($entries) {
      each as $e {
        math.add $total_correct {
          value = $e.correct_pick_count
        }
      
        math.add $total_scored {
          value = $e.scored_pick_count
        }
      }
    }
  
    var $avg_accuracy {
      value = ($total_scored > 0) ? (($total_correct / $total_scored)|round:3) : null
    }
  
    db.query user_bracket {
      where = $db.user_bracket.user_id == $input.id && $db.user_bracket.rank != null
      sort = {user_bracket.rank: "asc"}
      return = {type: "single"}
    } as $best_entry
  
    var $best_rank {
      value = ($best_entry != null) ? $best_entry.rank : null
    }
  
    // Recent finishes: last 5 ranked entries with tournament names
    db.query user_bracket {
      where = $db.user_bracket.user_id == $input.id && $db.user_bracket.rank != null
      sort = {user_bracket.created_at: "desc"}
      return = {type: "list", paging: {page: 1, per_page: 5}}
    } as $recent_page
  
    var $recent_finishes {
      value = []
    }
  
    foreach ($recent_page.items) {
      each as $finish {
        db.get tournament {
          field_name = "id"
          field_value = $finish.tournament_id
          output = ["id", "name", "slug", "year"]
        } as $finish_tournament
      
        array.push $recent_finishes {
          value = ```
            {
              tournament_id  : $finish.tournament_id
              tournament_name: ($finish_tournament != null) ? $finish_tournament.name : null
              tournament_slug: ($finish_tournament != null) ? $finish_tournament.slug : null
              rank           : $finish.rank
              total_points   : $finish.total_points
            }
            ```
        }
      }
    }
  }

  response = {
    user           : $profile
    stats          : {entries: $entries_count, best_rank: $best_rank, avg_accuracy: $avg_accuracy}
    recent_finishes: $recent_finishes
  }
}
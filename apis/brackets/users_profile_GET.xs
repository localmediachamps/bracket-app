// Public mini-profile: user card, aggregate stats (entries, best rank, average
// accuracy across scored picks), the 5 most recent ranked finishes, and (if
// the owner opted in via show_public_submissions) a combined list of every
// public bracket/pick'em submission with points earned toward the master
// leaderboard - clicking a rank on platform/leaderboard lands here, and from
// here a viewer can click through to the actual submission (still gated by
// that submission's own is_public + the viewer being logged in, same rule as
// everywhere else entries are viewed).
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
        id                     : $user.id
        username               : $user.username
        display_name           : $user.display_name
        avatar_url             : $user.avatar_url
        bio                    : $user.bio
        favorite_school        : $user.favorite_school
        created_at             : $user.created_at
        show_public_submissions: $user.show_public_submissions
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
      value = null
    }
  
    conditional {
      if ($total_scored > 0) {
        var.update $avg_accuracy {
          value = (($total_correct / $total_scored)|round:3)
        }
      }
    }
  
    db.query user_bracket {
      where = $db.user_bracket.user_id == $input.id && $db.user_bracket.rank != null
      sort = {user_bracket.rank: "asc"}
      return = {type: "single"}
    } as $best_entry
  
    var $best_rank {
      value = null
    }
  
    conditional {
      if (($best_entry != null)) {
        var.update $best_rank {
          value = $best_entry.rank
        }
      }
    
      else {
        var.update $best_rank {
          value = null
        }
      }
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
      
        var $ft_name {
          value = null
        }
      
        var $ft_slug {
          value = null
        }
      
        conditional {
          if ($finish_tournament != null) {
            var.update $ft_name {
              value = $finish_tournament.name
            }
          
            var.update $ft_slug {
              value = $finish_tournament.slug
            }
          }
        }
      
        array.push $recent_finishes {
          value = {
            tournament_id  : $finish.tournament_id
            tournament_name: $ft_name
            tournament_slug: $ft_slug
            rank           : $finish.rank
            total_points   : $finish.total_points
          }
        }
      }
    }

    // Public submissions list - every bracket/pick'em entry this user has
    // made public, each merged with its platform_leaderboard_entry points
    // (if that tournament has been ranked into the master leaderboard yet).
    // Gated on show_public_submissions - a separate opt-in from is_public on
    // each individual entry, and from leaderboard_visible (which only
    // affects showing up in leaderboard rankings, not this profile list).
    var $submissions {
      value = []
    }

    var $submissions_visible {
      value = $user.show_public_submissions != false
    }

    conditional {
      if ($submissions_visible) {
        db.query platform_leaderboard_entry {
          where = $db.platform_leaderboard_entry.user_id == $input.id
          return = {type: "list"}
        } as $ple_rows

        var $ple_lookup {
          value = {}
        }

        var $ple_dm_lookup {
          value = {}
        }

        foreach ($ple_rows) {
          each as $ple {
            conditional {
              if ($ple.source_type == "dual_meet") {
                var $ple_dm_key {
                  value = $ple.dual_meet_id|to_text
                }

                var.update $ple_dm_lookup {
                  value = $ple_dm_lookup|set:$ple_dm_key:$ple.points_awarded
                }
              }
              else {
                var $ple_key {
                  value = $ple.tournament_id|to_text|concat:$ple.source_type:"_"
                }

                var.update $ple_lookup {
                  value = $ple_lookup|set:$ple_key:$ple.points_awarded
                }
              }
            }
          }
        }

        db.query user_bracket {
          where = $db.user_bracket.user_id == $input.id && $db.user_bracket.is_public == true
          return = {type: "list"}
        } as $public_brackets

        foreach ($public_brackets) {
          each as $pb {
            db.get tournament {
              field_name = "id"
              field_value = $pb.tournament_id
              output = ["id", "name", "slug", "year"]
            } as $pb_tournament

            var $pb_t_name {
              value = null
            }

            var $pb_t_slug {
              value = null
            }

            var $pb_t_year {
              value = null
            }

            conditional {
              if ($pb_tournament != null) {
                var.update $pb_t_name {
                  value = $pb_tournament.name
                }

                var.update $pb_t_slug {
                  value = $pb_tournament.slug
                }

                var.update $pb_t_year {
                  value = $pb_tournament.year
                }
              }
            }

            var $pb_key {
              value = $pb.tournament_id|to_text|concat:"bracket":"_"
            }

            var $pb_points {
              value = null
            }

            conditional {
              if ($ple_lookup|has:$pb_key) {
                var.update $pb_points {
                  value = $ple_lookup|get:$pb_key:null
                }
              }
            }

            array.push $submissions {
              value = {
                tournament_id  : $pb.tournament_id
                tournament_name: $pb_t_name
                tournament_slug: $pb_t_slug
                tournament_year: $pb_t_year
                source_type    : "bracket"
                entry_id       : $pb.id
                status         : $pb.status
                rank           : $pb.rank
                total_points   : $pb.total_points
                platform_points: $pb_points
                created_at     : $pb.created_at
              }
            }
          }
        }

        db.query pickem_entry {
          where = $db.pickem_entry.user_id == $input.id && $db.pickem_entry.is_public == true
          return = {type: "list"}
        } as $public_pickems

        foreach ($public_pickems) {
          each as $pe {
            db.get tournament {
              field_name = "id"
              field_value = $pe.tournament_id
              output = ["id", "name", "slug", "year"]
            } as $pe_tournament

            var $pe_t_name {
              value = null
            }

            var $pe_t_slug {
              value = null
            }

            var $pe_t_year {
              value = null
            }

            conditional {
              if ($pe_tournament != null) {
                var.update $pe_t_name {
                  value = $pe_tournament.name
                }

                var.update $pe_t_slug {
                  value = $pe_tournament.slug
                }

                var.update $pe_t_year {
                  value = $pe_tournament.year
                }
              }
            }

            var $pe_key {
              value = $pe.tournament_id|to_text|concat:"pickem":"_"
            }

            var $pe_points {
              value = null
            }

            conditional {
              if ($ple_lookup|has:$pe_key) {
                var.update $pe_points {
                  value = $ple_lookup|get:$pe_key:null
                }
              }
            }

            array.push $submissions {
              value = {
                tournament_id  : $pe.tournament_id
                tournament_name: $pe_t_name
                tournament_slug: $pe_t_slug
                tournament_year: $pe_t_year
                source_type    : "pickem"
                entry_id       : $pe.id
                status         : $pe.status
                rank           : $pe.rank
                total_points   : $pe.total_points
                platform_points: $pe_points
                created_at     : $pe.created_at
              }
            }
          }
        }

        db.query dual_meet_entry {
          where = $db.dual_meet_entry.user_id == $input.id && $db.dual_meet_entry.is_public == true
          return = {type: "list"}
        } as $public_dual_meets

        foreach ($public_dual_meets) {
          each as $de {
            db.get dual_meet {
              field_name = "id"
              field_value = $de.dual_meet_id
              output = ["id", "name", "slug", "year"]
            } as $de_dual_meet

            var $de_t_name {
              value = null
            }

            var $de_t_slug {
              value = null
            }

            var $de_t_year {
              value = null
            }

            conditional {
              if ($de_dual_meet != null) {
                var.update $de_t_name {
                  value = $de_dual_meet.name
                }

                var.update $de_t_slug {
                  value = $de_dual_meet.slug
                }

                var.update $de_t_year {
                  value = $de_dual_meet.year
                }
              }
            }

            var $de_key {
              value = $de.dual_meet_id|to_text
            }

            var $de_points {
              value = null
            }

            conditional {
              if ($ple_dm_lookup|has:$de_key) {
                var.update $de_points {
                  value = $ple_dm_lookup|get:$de_key:null
                }
              }
            }

            array.push $submissions {
              value = {
                tournament_id  : $de.dual_meet_id
                tournament_name: $de_t_name
                tournament_slug: $de_t_slug
                tournament_year: $de_t_year
                source_type    : "dual_meet"
                entry_id       : $de.id
                status         : $de.status
                rank           : $de.rank
                total_points   : $de.total_points
                platform_points: $de_points
                created_at     : $de.created_at
              }
            }
          }
        }

        var.update $submissions {
          value = $submissions|sort:"created_at":"number"|reverse
        }
      }
    }
  }

  response = {
    user               : $profile
    stats              : {entries: $entries_count, best_rank: $best_rank, avg_accuracy: $avg_accuracy}
    recent_finishes    : $recent_finishes
    submissions_visible: $submissions_visible
    submissions        : $submissions
  }
  guid = "28t_euRA2KqjlnGGsAhj2-eBgFY"
}
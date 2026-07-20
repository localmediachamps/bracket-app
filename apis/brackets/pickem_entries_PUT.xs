// Replace all picks on a pick'em entry. Validates: one pick per weight class of
// the tournament, wrestler belongs to the weight class, cost from
// pickem_config.seed_costs[seed] (or default), and total cost within budget.
// Updates points_used and tiebreakers on the entry.
query "pickem-entries/{id}" verb=PUT {
  api_group = "brackets"
  auth = "user"

  input {
    // Pick'em entry id
    int id
  
    // Full pick set: [{weight_class_id, wrestler_id}]
    json picks
  
    // Optional tiebreaker values
    decimal? tiebreaker_1?
  
    decimal? tiebreaker_2?
    decimal? tiebreaker_3?
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }
  
    db.get pickem_entry {
      field_name = "id"
      field_value = $input.id
    } as $entry
  
    precondition ($entry != null) {
      error_type = "notfound"
      error = "Pick'em entry not found."
    }
  
    precondition ($entry.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "You do not own this entry."
    }
  
    db.get tournament {
      field_name = "id"
      field_value = $entry.tournament_id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    // Editable window: entry draft/submitted and tournament open (or late entries)
    precondition (($entry.status == "draft" || $entry.status == "submitted") && ($tournament.status == "open" || ($tournament.allow_late_entries && ($tournament.status == "locked" || $tournament.status == "live")))) {
      error_type = "inputerror"
      error = "Entry is not editable."
    }
  
    // Pick'em config with default fallback
    var $config {
      value = $tournament.pickem_config
    }
  
    conditional {
      if ($config == null) {
        function.run get_default_pickem_config as $default_config
        var.update $config {
          value = $default_config
        }
      }
    }
  
    var $budget {
      value = $config.budget
    }
  
    var $total_cost {
      value = 0
    }
  
    var $seen_weight_classes {
      value = []
    }
  
    var $validated_picks {
      value = []
    }
  
    foreach ($input.picks) {
      each as $pick {
        precondition (($seen_weight_classes|some:$$ == $pick.weight_class_id) == false) {
          error_type = "inputerror"
          error = "Only one pick per weight class is allowed."
        }
      
        array.push $seen_weight_classes {
          value = $pick.weight_class_id
        }
      
        db.get weight_class {
          field_name = "id"
          field_value = $pick.weight_class_id
        } as $wc
      
        precondition ($wc != null && $wc.tournament_id == $tournament.id) {
          error_type = "inputerror"
          error = "Invalid weight class."
        }
      
        db.get wrestler {
          field_name = "id"
          field_value = $pick.wrestler_id
        } as $wrestler
      
        precondition ($wrestler != null && $wrestler.weight_class_id == $wc.id) {
          error_type = "inputerror"
          error = "Wrestler does not belong to this weight class."
        }
      
        // Cost from seed costs with default fallback
        var $seed_key {
          value = $wrestler.seed|to_text
        }
      
        var $cost {
          value = null
        }
      
        var $seed_costs_map {
          value = $config.seed_costs
        }
      
        conditional {
          if ($seed_costs_map|has:$seed_key) {
            var.update $cost {
              value = $seed_costs_map[$seed_key]
            }
          }
        }
      
        conditional {
          if ($cost == null) {
            var.update $cost {
              value = $config.seed_costs|get:"default"
            }
          }
        }
      
        conditional {
          if ($cost == null) {
            var.update $cost {
              value = 10
            }
          }
        }
      
        math.add $total_cost {
          value = $cost
        }
      
        array.push $validated_picks {
          value = {
            weight_class_id: $wc.id
            wrestler_id    : $wrestler.id
            cost           : $cost
          }
        }
      }
    }
  
    precondition ($total_cost <= $budget) {
      error_type = "inputerror"
      error = "Total pick cost exceeds the budget."
    }
  
    // Replace all picks: delete existing, insert the validated set
    db.query pickem_pick {
      where = $db.pickem_pick.pickem_entry_id == $entry.id
      return = {type: "list"}
    } as $old_picks
  
    foreach ($old_picks) {
      each as $old_pick {
        db.del pickem_pick {
          field_name = "id"
          field_value = $old_pick.id
        }
      }
    }
  
    foreach ($validated_picks) {
      each as $validated {
        db.add pickem_pick {
          data = {
            created_at     : now
            pickem_entry_id: $entry.id
            tournament_id  : $tournament.id
            weight_class_id: $validated.weight_class_id
            wrestler_id    : $validated.wrestler_id
            cost           : $validated.cost
            points_earned  : 0
          }
        } as $new_pick
      }
    }
  
    // Update spend + tiebreakers on the entry
    var $entry_payload {
      value = {points_used: $total_cost, updated_at: now}
    }
  
    conditional {
      if ($input.tiebreaker_1 != null) {
        var.update $entry_payload {
          value = $entry_payload
            |set:"tiebreaker_1":$input.tiebreaker_1
        }
      }
    }
  
    conditional {
      if ($input.tiebreaker_2 != null) {
        var.update $entry_payload {
          value = $entry_payload
            |set:"tiebreaker_2":$input.tiebreaker_2
        }
      }
    }
  
    conditional {
      if ($input.tiebreaker_3 != null) {
        var.update $entry_payload {
          value = $entry_payload
            |set:"tiebreaker_3":$input.tiebreaker_3
        }
      }
    }
  
    db.patch pickem_entry {
      field_name = "id"
      field_value = $entry.id
      data = $entry_payload
    } as $updated_entry
  }

  response = $updated_entry
}
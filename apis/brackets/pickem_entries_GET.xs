// Pick'em entry detail (owner only): entry plus picks with weight class info,
// wrestler summaries, cost, points earned, and scoring breakdown.
query "pickem-entries/{id}" verb=GET {
  api_group = "brackets"
  auth = "user"

  input {
    // Pick'em entry id
    int id
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
  
    db.query pickem_pick {
      where = $db.pickem_pick.pickem_entry_id == $entry.id
      return = {type: "list"}
    } as $picks
  
    var $pick_rows {
      value = []
    }
  
    foreach ($picks) {
      each as $p {
        db.get weight_class {
          field_name = "id"
          field_value = $p.weight_class_id
          output = ["id", "weight", "name"]
        } as $wc
      
        db.get wrestler {
          field_name = "id"
          field_value = $p.wrestler_id
          output = ["id", "name", "school", "seed"]
        } as $wrestler
      
        array.push $pick_rows {
          value = {
            id             : $p.id
            weight_class_id: $p.weight_class_id
            weight_class   : $wc
            wrestler       : $wrestler
            cost           : $p.cost
            points_earned  : $p.points_earned
            breakdown      : $p.breakdown
          }
        }
      }
    }
  }

  response = {entry: $entry, picks: $pick_rows}
}
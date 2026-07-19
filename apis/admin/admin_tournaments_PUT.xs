// Partial tournament update (ARCHITECTURE.md section 6: PUT /admin/tournaments/{id}).
// Updates scalar/config fields only — status changes go through POST .../status.
// When the tournament is live or completed the change is audit-logged.
query "admin/tournaments/{id}" verb=PUT {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
  
    text? name? filters=trim
    int? year?
  
    // Slug change — slugified and checked for uniqueness
    text? slug? filters=trim|lower
  
    text? description?
    text? location?
    date? start_date?
    date? end_date?
    timestamp? locks_at?
  
    // public | unlisted
    text? visibility? filters=trim|lower
  
    json? game_modes?
    json? scoring_config?
    json? pickem_config?
    bool? show_pick_percentages?
    bool? allow_late_entries?
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    db.get tournament {
      field_name = "id"
      field_value = $input.id
    } as $tournament
  
    precondition ($tournament != null) {
      error_type = "notfound"
      error = "Tournament not found."
    }
  
    precondition ($input.visibility == null || $input.visibility == "public" || $input.visibility == "unlisted") {
      error_type = "inputerror"
      error = "visibility must be public or unlisted."
    }
  
    // Slug: clean and enforce uniqueness (excluding this tournament)
    var $slug_value {
      value = null
    }
  
    conditional {
      if ($input.slug != null && ($input.slug|strlen) > 0) {
        function.run slugify {
          input = {text: $input.slug}
        } as $clean_slug
      
        db.query tournament {
          where = $db.tournament.slug == $clean_slug && $db.tournament.id != $input.id
          return = {type: "count"}
        } as $slug_hits
      
        precondition ($slug_hits == 0) {
          error_type = "inputerror"
          error = "Slug is already in use by another tournament."
        }
      
        var.update $slug_value {
          value = $clean_slug
        }
      }
    }
  
    // Build the patch payload from provided (non-null) fields only.
    // Note: absent keys are left untouched; fields cannot be cleared to null here.
    var $payload {
      value = {}
    }
  
    var.update $payload {
      value = $payload
        |set_ifnotnull:"name":$input.name
        |set_ifnotnull:"year":$input.year
        |set_ifnotnull:"slug":$slug_value
    }
  
    var.update $payload {
      value = $payload
        |set_ifnotnull:"description":$input.description
        |set_ifnotnull:"location":$input.location
        |set_ifnotnull:"start_date":$input.start_date
    }
  
    var.update $payload {
      value = $payload
        |set_ifnotnull:"end_date":$input.end_date
        |set_ifnotnull:"locks_at":$input.locks_at
        |set_ifnotnull:"visibility":$input.visibility
    }
  
    var.update $payload {
      value = $payload
        |set_ifnotnull:"game_modes":$input.game_modes
        |set_ifnotnull:"scoring_config":$input.scoring_config
        |set_ifnotnull:"pickem_config":$input.pickem_config
    }
  
    var.update $payload {
      value = $payload
        |set_ifnotnull:"show_pick_percentages":$input.show_pick_percentages
        |set_ifnotnull:"allow_late_entries":$input.allow_late_entries
    }
  
    precondition (($payload|keys|count) > 0) {
      error_type = "inputerror"
      error = "No updatable fields provided."
    }
  
    db.patch tournament {
      field_name = "id"
      field_value = $input.id
      data = $payload
    } as $updated
  
    // Audited when the tournament is live or completed (results may exist)
    conditional {
      if ($tournament.status == "live" || $tournament.status == "completed") {
        function.run audit {
          input = {
            actor_id      : $auth.id
            entity_type   : "tournament"
            entity_id     : $input.id
            action        : "tournament_updated"
            previous_value: $tournament
            new_value     : $updated
          }
        } as $audit_row
      }
    }
  }

  response = $updated
}
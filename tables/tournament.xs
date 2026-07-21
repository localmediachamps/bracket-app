table tournament {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    text name
    int year
  
    // url-safe slug from name+year
    text slug filters=trim|lower
  
    text description?
    text location?
    date start_date?
    date end_date?
  
    // prediction deadline — entries lock when this passes
    timestamp locks_at?
  
    // state machine: draft | importing | needs_review | open | locked | live | completed | archived | cancelled
    text status?=draft
  
    // public | unlisted
    text visibility?=public
  
    // enabled game modes, e.g. ["bracket","pickem"] — default both applied in code
    json game_modes?
  
    // versioned scoring configuration (see ARCHITECTURE.md section 5)
    json scoring_config?
  
    // pick'em salary-cap configuration (see ARCHITECTURE.md section 7)
    json pickem_config?
  
    // reveal pick popularity before lock
    bool show_pick_percentages?
  
    bool allow_late_entries?
  
    // FK to user.id
    int created_by?
  
    timestamp published_at?
  
    // FK to uploaded_document.id when created via PDF import
    int source_document_id?
  
    // dirty flag for task-based scoring
    bool needs_rescore?
  
    // denormalized count of submitted+draft entries
    int entry_count?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "slug", op: "asc"}]}
    {type: "btree", field: [{name: "status", op: "asc"}]}
    {type: "btree", field: [{name: "year", op: "desc"}]}
  ]
  guid = "xl0ssvJgtAynMwVSVLJYq4sggZE"
}
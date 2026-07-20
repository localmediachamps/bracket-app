// Admin tournament overview: the full tournament record plus its weight classes
// (ids, weights, names, display order, template, size, competitor counts, status),
// entry and group counts. Admins need this for draft tournaments, which the public
// overview endpoint never returns.
query "admin/tournaments/{id}" verb=GET {
  api_group = "admin"
  auth = "user"

  input {
    // Tournament ID
    int id
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
  
    db.query weight_class {
      where = $db.weight_class.tournament_id == $input.id
      sort = {weight_class.display_order: "asc"}
      return = {type: "list"}
    } as $weight_classes
  
    db.query user_bracket {
      where = $db.user_bracket.tournament_id == $input.id
      return = {type: "count"}
    } as $entry_count
  
    db.query fantasy_group {
      where = $db.fantasy_group.tournament_id == $input.id
      return = {type: "count"}
    } as $group_count
  
    db.query uploaded_document {
      where = $db.uploaded_document.tournament_id == $input.id
      sort = {uploaded_document.created_at: "desc"}
      return = {type: "list"}
      output = ["id", "file_name", "processing_status", "created_at"]
    } as $documents
  }

  response = {
    tournament    : $tournament
    weight_classes: $weight_classes
    entry_count   : $entry_count
    group_count   : $group_count
    documents     : $documents
  }
}
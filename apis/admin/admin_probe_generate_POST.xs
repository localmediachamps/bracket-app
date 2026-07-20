// Temporary diagnostic endpoint: runs the staged probe for the bracket generator.
// DELETE after the generator is verified healthy.
query "admin/probe/generate" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    int stage filters=min:1|max:14
    int weight_class_id
    int tournament_id
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin
  
    function.run probe_generate {
      input = {
        stage          : $input.stage
        weight_class_id: $input.weight_class_id
        tournament_id  : $input.tournament_id
      }
    } as $result
  }

  response = $result
}
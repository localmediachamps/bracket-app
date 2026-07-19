// Ranked leaderboard of a fantasy group's active members (delegates to the
// group_leaderboard function).
query "groups/{id}/leaderboard" verb=GET {
  api_group = "brackets"

  input {
    // Group id
    int id
  
    // bracket or pickem
    text? mode?=bracket filters=trim|lower
  
    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    function.run group_leaderboard {
      input = {
        group_id: $input.id
        mode    : $input.mode
        page    : $input.page
        per     : $input.per
      }
    } as $board
  }

  response = $board
}
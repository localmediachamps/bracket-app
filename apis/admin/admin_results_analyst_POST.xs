// Admin-only test surface for the Results Analyst AI agent scaffolding
// (POST /admin/results-analyst). Not a public feature yet - lets an admin
// (or this repo's own tooling) exercise the agent + search_match_results
// tool end-to-end before any real frontend surface is built for it.
query "admin/results-analyst" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    text message filters=trim|min:1
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    ai.agent.run "Results Analyst" {
      args = {}|set:"message":$input.message
      allow_tool_execution = true
    } as $agent_result
  }

  response = $agent_result
  guid = "u4-tPG9lrUGB_gNA2Jb5yrDSZ5w"
}

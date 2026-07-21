// League-member surface for the Results Analyst AI agent - same agent and
// search_match_results tool as the admin test surface
// (apis/admin/admin_results_analyst_POST.xs, left unchanged), just gated on
// active league membership instead of site-admin so drafting/lineup-setting
// members can use it as a decision-support tool.
query "leagues/results-analyst" verb=POST {
  api_group = "league"
  auth = "user"

  input {
    int league_id
    text message filters=trim|min:1
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "unauthorized"
      error = "Authentication required."
    }

    db.query league_membership {
      where = $db.league_membership.league_id == $input.league_id && $db.league_membership.user_id == $auth.id && $db.league_membership.status == "active"
      return = {type: "exists"}
    } as $is_member

    precondition ($is_member) {
      error_type = "accessdenied"
      error = "You must be an active member of this league to use the analyst."
    }

    ai.agent.run "Results Analyst" {
      args = {}|set:"message":$input.message
      allow_tool_execution = true
    } as $agent_result
  }

  response = $agent_result
  guid = "sa9lTNbG5Sw7X2BWh1U7WWKWcc4"
}

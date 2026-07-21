// A private, season-long fantasy league - deliberately its own table rather
// than reusing fantasy_group, since fantasy_group is hard-scoped to one
// tournament_id and a season league spans an entire season and many events.
table league {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp updated_at?

    int? season_id? {
      table = "season"
    }

    int? owner_id? {
      table = "user"
    }

    text name filters=trim
    text slug filters=trim|lower
    text description? filters=trim

    enum privacy?="private" {
      values = ["private", "unlisted"]
    }

    // 8-char unique code, reuse functions/utils/invite_code.xs at creation
    text invite_code filters=trim

    int member_limit?
    int member_count?
    text avatar_emoji?

    enum status?="forming" {
      values = ["forming", "drafting", "active", "completed"]
    }

    // Overlays functions/utils/get_default_league_config.xs's output -
    // victory_points, medal_bonus, opponent multiplier tiers, placement_points
    json? scoring_config?

    int roster_starter_slots?=10
    int roster_alternate_slots?=2

    // Draft timing/format settings (pick time limit, snake order seed, etc.)
    json? draft_config?

    // How many fantasy teams qualify for each bowl conference tier -
    // {"Big Ten": 2, "ACC": 2, ...} - scales with league size
    json? bowl_config?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "invite_code", op: "asc"}]}
    {type: "btree", field: [{name: "season_id", op: "asc"}]}
    {type: "btree", field: [{name: "owner_id", op: "asc"}]}
    {type: "btree|unique", field: [{name: "season_id", op: "asc"}, {name: "slug", op: "asc"}]}
  ]
  guid = "dd3iOXT-HMfuqdeh6uujKiA8va8"
}

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

    // NOT a commissioner setting - college wrestling always has one starter
    // slot per weight class, so this is derived from the season's own
    // season_weight_class count wherever rounds/roster size are computed
    // (see leagues_draft_start_POST.xs), never edited directly. Kept as a
    // stored field for display/back-compat rather than dropped.
    int roster_starter_slots?=10

    // Which of the two alternate models this league uses - see
    // roster_alternate_slots / roster_alternate_pool_size below.
    enum roster_alternate_mode?="per_weight" {
      values = ["per_weight", "flat_pool"]
    }

    // roster_alternate_mode=per_weight only: alternates PER weight class,
    // default 1 means one bench/backup slot at every weight, so a 10-weight
    // season gives each team roster_starter_slots + (roster_alternate_slots
    // * 10) total slots. Ignored when mode=flat_pool.
    int roster_alternate_slots?=1

    // roster_alternate_mode=flat_pool only: a single bench pool size shared
    // across ALL weights (e.g. 5 total bench spots the team can stack
    // however they want - three backup 125s and none anywhere else is
    // legal). Ignored when mode=per_weight.
    int? roster_alternate_pool_size?=5

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

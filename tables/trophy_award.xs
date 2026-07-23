// One row per actual recipient of an actual trophy. For tournament-scope
// awards, image_url is copied straight from the matching trophy_template
// (cheap - no generation at award time). For league-scope awards (deferred
// until league/season finality exists), image_url is the personalized
// plaque-baked variant unique to this recipient.
table trophy_award {
  auth = false

  schema {
    int id
    timestamp awarded_at?=now

    int recipient_user_id {
      table = "user"
    }

    enum context_type {
      values = ["tournament_bracket", "tournament_pickem", "league_season"]
    }

    // tournament id, or league id once the league-award trigger is wired up
    int context_id

    int placement

    int? template_id? {
      table = "trophy_template"
    }

    text image_url

    // Drives the one-time reveal-ceremony animation
    bool seen?=false
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "recipient_user_id", op: "asc"}
        {name: "context_type", op: "asc"}
        {name: "context_id", op: "asc"}
        {name: "placement", op: "asc"}
      ]
    }
    {
      type : "btree"
      field: [
        {name: "context_type", op: "asc"}
        {name: "context_id", op: "asc"}
        {name: "placement", op: "asc"}
      ]
    }
  ]
  guid = "HbiUDEFi948pagVSpUkJ0kRfqWo"
}

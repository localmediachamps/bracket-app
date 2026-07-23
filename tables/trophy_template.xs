// One row per designed base trophy image. Both tracks share this table,
// distinguished by scope: "tournament" rows are a small fixed admin-managed
// library (one per real recurring tournament name x placement, reused every
// year that tournament completes); "league" rows are commissioner-designed
// via the interactive builder (one per league x placement, personalized
// with a plaque only at actual award time - see trophy_award).
table trophy_template {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?

    enum scope {
      values = ["tournament", "league"]
    }

    // scope=tournament only - matched against tournament.name at award time
    text? tournament_name? filters=trim

    // True only for the NCAA Championships row - steers a more elaborate
    // "extra pizzazz" prompt variant
    bool? is_marquee?

    // scope=league only
    int? owner_league_id? {
      table = "league"
    }

    // 1st/2nd/3rd
    int placement

    text? image_url?
    text? generation_prompt?

    // Responses API continuity token - lets a later "iterate" call
    // reference this exact generation state
    text? openai_response_id?

    enum generation_status?="pending" {
      values = ["pending", "generating", "ready", "failed"]
    }

    // Structured preset choices (style/material/color/pillar keys) that
    // produced the current image, so the builder UI can re-render its own
    // picker state on reload
    json? design_inputs?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "scope", op: "asc"}
        {name: "tournament_name", op: "asc"}
        {name: "placement", op: "asc"}
      ]
    }
    {
      type : "btree|unique"
      field: [
        {name: "scope", op: "asc"}
        {name: "owner_league_id", op: "asc"}
        {name: "placement", op: "asc"}
      ]
    }
  ]
  guid = "iYeD0XPw9uzXb0mj8EgKkHlLMeo"
}

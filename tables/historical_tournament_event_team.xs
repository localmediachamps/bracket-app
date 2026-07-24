// Which real teams actually sent wrestlers to a given historical tournament
// event, and how many of those were that team's STARTERS (canonical_wrestler_
// team.is_starter) vs backups - the exact signal needed to answer "if we
// make this a marquee week, would league rosters actually be represented,
// or would half the league be forced to bench real starters who never
// attend this event" (e.g. Penn State's well-known pattern of skipping most
// regular-season tournaments with their top lineup).
table historical_tournament_event_team {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int event_id {
      table = "historical_tournament_event"
    }

    int? canonical_team_id? {
      table = "canonical_team"
    }

    text team_name_raw filters=trim

    int wrestler_count?
    int starter_count?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "event_id", op: "asc"}]}
    {type: "btree", field: [{name: "canonical_team_id", op: "asc"}]}
  ]
  guid = "Yp9nWo4XkRt6MdSqZu7IcKe3GhXf5"
}

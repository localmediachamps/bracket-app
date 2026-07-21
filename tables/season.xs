// The season-spanning container that fantasy leagues, the schedule, and
// composite rankings all attach to. Distinct from `tournament` (one
// standalone bracket/pickem event) - a season contains many real events
// across a whole wrestling year.
table season {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    text name filters=trim
    int year
    text slug filters=trim|lower

    date start_date?
    date end_date?

    enum status?="upcoming" {
      values = ["upcoming", "active", "completed"]
    }

    text division?="d1" filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "slug", op: "asc"}]}
    {type: "btree", field: [{name: "year", op: "desc"}]}
  ]
  guid = "jDMdwNrsliNsjDPSn-C51MWqjn0"
}

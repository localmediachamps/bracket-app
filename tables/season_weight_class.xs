// Season-level weight-class catalog for the fantasy league (draft slots,
// roster structure). Distinct from `weight_class`, which is scoped to one
// standalone tournament, not a season.
table season_weight_class {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? season_id? {
      table = "season"
    }

    int weight
    text name? filters=trim
    int display_order?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "season_id", op: "asc"}, {name: "weight", op: "asc"}]}
  ]
  guid = "mBXb-FkUXx_-8ydLx3QMpFNv1JI"
}

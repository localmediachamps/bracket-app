// A user's own personal composite ranking per weight class - independent
// from the official wrestler_composite_ranking (admin-managed). Lets any
// user build and publicly show off "my rankings" on their profile - the
// social/bragging half of Mat Savvy ("I told you so, this guy was
// underrated"), separate from the official board. If enough users build
// their own lists, the aggregate could eventually inform the official
// composite (Garrett's idea, not built yet - needs real critical mass
// first).
table user_wrestler_ranking {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?

    int user_id
    int canonical_wrestler_id
    int weight
    int season_year
    int rank
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "user_id", op: "asc"}
        {name: "canonical_wrestler_id", op: "asc"}
        {name: "weight", op: "asc"}
        {name: "season_year", op: "asc"}
      ]
    }
    {
      type : "btree"
      field: [
        {name: "user_id", op: "asc"}
        {name: "weight", op: "asc"}
        {name: "season_year", op: "asc"}
      ]
    }
  ]
  guid = "P9xVq4ZtNs7RyWzJo3HbFd6GkEc5"
}

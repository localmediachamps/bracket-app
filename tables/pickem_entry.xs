table pickem_entry {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int user_id
    int tournament_id
  
    // draft | submitted | locked
    text status?=draft

    // Owner opt-in to let other users view this entry's picks from the
    // tournament leaderboard. Defaults to private.
    bool is_public?=false

    // salary-cap points spent
    int points_used?
  
    decimal tiebreaker_1?
    decimal tiebreaker_2?
    decimal tiebreaker_3?
    decimal total_points?
    int rank?
    int prev_rank?
    timestamp submitted_at?
    timestamp locked_at?
    timestamp updated_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "user_id", op: "asc"}
        {name: "tournament_id", op: "asc"}
      ]
    }
    {type: "btree", field: [{name: "tournament_id", op: "asc"}]}
    {type: "btree", field: [{name: "total_points", op: "desc"}]}
  ]
  guid = "tAix7Fjaz2P_t3Pt2HJBsv9_M34"
}
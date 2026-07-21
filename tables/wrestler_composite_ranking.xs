// Composite national ranking per wrestler per weight, sourced from multiple
// outlets (FloWrestling, InterMat, etc. - see fantasy league plan, dependency
// D). Not yet populated by any ingestion pipeline - this table exists so the
// bracket scoring engine's opponent-quality multiplier (contender/
// all-american/blood-round tiers) has a real place to look up a rank once
// that pipeline is built. Until then, every lookup returns no rows and the
// multiplier is a no-op (1x).
table wrestler_composite_ranking {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int canonical_wrestler_id
    int weight
    int season_year
    int rank
    int? source_count?
    timestamp updated_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "canonical_wrestler_id", op: "asc"}
        {name: "weight", op: "asc"}
        {name: "season_year", op: "asc"}
      ]
    }
    {type: "btree", field: [{name: "rank", op: "asc"}]}
  ]
  guid = "IHE5MOTTVw2iFsAOWaC899HSuU0"
}

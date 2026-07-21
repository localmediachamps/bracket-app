// One row per user in a league. Mirrors group_membership's shape but FKs
// league instead of fantasy_group.
table league_membership {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int? league_id? {
      table = "league"
    }

    int? user_id? {
      table = "user"
    }

    enum role?="member" {
      values = ["owner", "commissioner", "member"]
    }

    enum status?="active" {
      values = ["active", "pending", "invited", "removed"]
    }

    timestamp joined_at?

    // Snake-draft position, set when the commissioner seeds the draft
    int draft_position?

    int wins?=0
    int losses?=0
    decimal points_for?=0
    decimal points_against?=0
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "league_id", op: "asc"}, {name: "user_id", op: "asc"}]}
    {type: "btree", field: [{name: "user_id", op: "asc"}]}
  ]
  guid = "INI9qtQSii7opwiRnvMALYuFIMM"
}

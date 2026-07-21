// One row per user's paid entitlement. status mirrors Stripe's own
// subscription status values directly (don't invent a parallel vocabulary).
// Unique on (user_id, plan_key) - a user could have more than one plan_key
// in the future even though only "annual" exists today.
table subscription {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int user_id
    text stripe_customer_id
    text? stripe_subscription_id?
    text plan_key
    text status?=incomplete
    timestamp? current_period_end?
    timestamp? updated_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [
        {name: "user_id", op: "asc"}
        {name: "plan_key", op: "asc"}
      ]
    }
    {type: "btree", field: [{name: "stripe_customer_id", op: "asc"}]}
    {type: "btree", field: [{name: "stripe_subscription_id", op: "asc"}]}
  ]
  guid = "wdeqHU1Koc4ICTTz7Lf6eQxg1Jc"
}

// Receives Stripe webhook events and upserts the subscription row.
// No user auth - Stripe calls this directly.
//
// Authenticity note: XanoScript does not expose a way to read the incoming
// "Stripe-Signature" header (confirmed empirically - util.get_vars,
// util.get_all_input, and a bare $headers reference all fail to surface it;
// Xano's own official Stripe Checkout extension, installed in this
// workspace at api:UQuTJ3vx, has the identical gap - its webhooks_POST.xs
// trusts the raw body with no HMAC check at all). Rather than trust the
// webhook payload directly, every branch below re-fetches the real object
// from Stripe's API using our own stripe_secret_key before acting on it.
// An attacker can still hit this URL with a fake event naming a real
// session/subscription/invoice id, but the DATA we act on always comes from
// our own authenticated GET back to Stripe, never from the untrusted
// payload - at worst a forged call triggers a harmless, idempotent re-sync
// of an object's already-true state.
query "billing/webhook" verb=POST {
  api_group = "billing"

  input {
  }

  stack {
    util.get_raw_input {
      encoding = "json"
    } as $raw_payload

    var $event_type {
      value = $raw_payload|get:"type":""
    }

    var $obj {
      value = $raw_payload|get:"data":{}|get:"object":{}
    }

    var $auth_header {
      value = []|push:("Authorization: Bearer " ~ $env.stripe_secret_key)
    }

    conditional {
      if ($event_type == "checkout.session.completed") {
        var $session_id {
          value = $obj|get:"id":null
        }

        conditional {
          if ($session_id != null) {
            api.request {
              url = "https://api.stripe.com/v1/checkout/sessions/" ~ $session_id
              method = "GET"
              headers = $auth_header
              timeout = 30
            } as $session_fetch

            var $real_session {
              value = $session_fetch.response.result
            }

            var $user_id {
              value = $real_session|get:"client_reference_id":null|to_int
            }

            conditional {
              if ($user_id != null && $user_id > 0 && $real_session|get:"payment_status":"" == "paid") {
                db.add_or_edit subscription {
                  field_name = "user_id"
                  field_value = $user_id
                  data = {
                    user_id               : $user_id
                    plan_key              : "annual"
                    stripe_customer_id    : $real_session|get:"customer":""
                    stripe_subscription_id: $real_session|get:"subscription":null
                    status                : "active"
                    updated_at            : now
                  }
                } as $sub_row
              }
            }
          }
        }
      }

      elseif ($event_type == "customer.subscription.updated" || $event_type == "customer.subscription.deleted") {
        var $stripe_sub_id {
          value = $obj|get:"id":null
        }

        conditional {
          if ($stripe_sub_id != null) {
            api.request {
              url = "https://api.stripe.com/v1/subscriptions/" ~ $stripe_sub_id
              method = "GET"
              headers = $auth_header
              timeout = 30
            } as $sub_fetch

            var $real_sub {
              value = $sub_fetch.response.result
            }

            conditional {
              if ($real_sub|get:"id":null != null) {
                db.query subscription {
                  where = $db.subscription.stripe_subscription_id == $stripe_sub_id
                  return = {type: "single"}
                } as $existing

                conditional {
                  if ($existing != null) {
                    var $period_end_raw {
                      value = $real_sub|get:"current_period_end":null
                    }

                    var $period_end {
                      value = null
                    }

                    conditional {
                      if ($period_end_raw != null) {
                        var.update $period_end {
                          value = ($period_end_raw * 1000)|to_timestamp
                        }
                      }
                    }

                    db.edit subscription {
                      field_name = "id"
                      field_value = $existing.id
                      data = {
                        status            : $real_sub|get:"status":"canceled"
                        current_period_end: $period_end
                        updated_at        : now
                      }
                    } as $updated_sub
                  }
                }
              }
            }
          }
        }
      }

      elseif ($event_type == "invoice.payment_failed" || $event_type == "invoice.payment_succeeded") {
        var $invoice_id {
          value = $obj|get:"id":null
        }

        conditional {
          if ($invoice_id != null) {
            api.request {
              url = "https://api.stripe.com/v1/invoices/" ~ $invoice_id
              method = "GET"
              headers = $auth_header
              timeout = 30
            } as $invoice_fetch

            var $real_invoice {
              value = $invoice_fetch.response.result
            }

            var $invoice_sub_id {
              value = $real_invoice|get:"subscription":null
            }

            conditional {
              if ($invoice_sub_id != null) {
                api.request {
                  url = "https://api.stripe.com/v1/subscriptions/" ~ $invoice_sub_id
                  method = "GET"
                  headers = $auth_header
                  timeout = 30
                } as $inv_sub_fetch

                var $real_inv_sub {
                  value = $inv_sub_fetch.response.result
                }

                conditional {
                  if ($real_inv_sub|get:"id":null != null) {
                    db.query subscription {
                      where = $db.subscription.stripe_subscription_id == $invoice_sub_id
                      return = {type: "single"}
                    } as $existing_by_sub

                    conditional {
                      if ($existing_by_sub != null) {
                        db.edit subscription {
                          field_name = "id"
                          field_value = $existing_by_sub.id
                          data = {
                            status    : $real_inv_sub|get:"status":"past_due"
                            updated_at: now
                          }
                        } as $updated_from_invoice
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  response = {received: true}
  guid = "ZHGqlUyzv8CZ9-JNNgs2PdzedOs"
}

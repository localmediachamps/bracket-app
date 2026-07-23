// Public list of dual meets, newest first. Filterable by status/year.
query "dual-meets" verb=GET {
  api_group = "brackets"

  input {
    text? status? filters=trim|lower
    int? year?

    // true = only bulk-reconciled real historical results (see
    // functions/analytics/reconcile_historical_dual_meets.xs); false = only
    // predictable/pick'em dual meets; omitted = both (existing behavior)
    bool? is_historical?

    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    db.query dual_meet {
      where = $db.dual_meet.status ==? $input.status && $db.dual_meet.year ==? $input.year && $db.dual_meet.visibility == "public" && $db.dual_meet.is_historical ==? $input.is_historical
      sort = {dual_meet.occurred_at: "desc"}
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per, totals: true}
      }
    } as $result
  }

  response = {
    items: $result.items
    total: $result.itemsTotal
    page : $input.page
    per  : $input.per
  }
  guid = "qoyAMDDQ8DzcGBOnLW168Ihu4Dg"
}

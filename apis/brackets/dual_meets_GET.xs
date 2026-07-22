// Public list of dual meets, newest first. Filterable by status/year.
query "dual-meets" verb=GET {
  api_group = "brackets"

  input {
    text? status? filters=trim|lower
    int? year?
    int page?=1 filters=min:1
    int per?=25 filters=min:1|max:100
  }

  stack {
    db.query dual_meet {
      where = $db.dual_meet.status ==? $input.status && $db.dual_meet.year ==? $input.year && $db.dual_meet.visibility == "public"
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

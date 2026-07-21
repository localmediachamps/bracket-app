// Create a fantasy-league season (e.g. "2025-26 NCAA D1"). Admin-only -
// there's no self-serve season creation; Garrett sets these up once per year.
query "admin/seasons" verb=POST {
  api_group = "admin"
  auth = "user"

  input {
    text name filters=trim|min:1
    int year
    date? start_date?
    date? end_date?
    text? division?=d1 filters=trim
  }

  stack {
    function.run validate_admin {
      input = {user_id: $auth.id}
    } as $admin

    function.run slugify {
      input = {text: $input.name}
    } as $slug

    conditional {
      if ($slug == null || ($slug|strlen) == 0) {
        var.update $slug {
          value = "season"
        }
      }
    }

    db.query season {
      where = $db.season.slug == $slug
      return = {type: "exists"}
    } as $slug_taken

    precondition ($slug_taken == false) {
      error_type = "inputerror"
      error = "A season with this name/slug already exists."
    }

    db.add season {
      data = {
        created_at: now
        name      : $input.name
        year      : $input.year
        slug      : $slug
        start_date: $input.start_date
        end_date  : $input.end_date
        division  : $input.division|first_notempty:"d1"
      }
    } as $season
  }

  response = $season
  guid = "J8oFDZiub2HP62JXtNIRppFK_wE"
}

// Public trophy shelf for a user's profile - every trophy_award row for
// this user, newest first. No auth, same as the rest of the public profile
// (rankings, submissions).
query "users/{id}/trophies" verb=GET {
  api_group = "brackets"

  input {
    int id
  }

  stack {
    db.query trophy_award {
      where = $db.trophy_award.recipient_user_id == $input.id
      sort = {trophy_award.awarded_at: "desc"}
      return = {type: "list"}
    } as $awards

    var $out { value = [] }

    foreach ($awards) {
      each as $a {
        var $context_name { value = null }
        var $context_slug { value = null }

        conditional {
          if ($a.context_type == "tournament_bracket" || $a.context_type == "tournament_pickem") {
            db.get tournament {
              field_name = "id"
              field_value = $a.context_id
              output = ["id", "name", "slug"]
            } as $t

            conditional {
              if ($t != null) {
                var.update $context_name { value = $t.name }
                var.update $context_slug { value = $t.slug }
              }
            }
          }
          else {
            db.get league {
              field_name = "id"
              field_value = $a.context_id
              output = ["id", "name", "slug"]
            } as $lg

            conditional {
              if ($lg != null) {
                var.update $context_name { value = $lg.name }
                var.update $context_slug { value = $lg.slug }
              }
            }
          }
        }

        array.push $out {
          value = {
            id          : $a.id
            context_type: $a.context_type
            context_id  : $a.context_id
            context_name: $context_name
            context_slug: $context_slug
            placement   : $a.placement
            image_url   : $a.image_url
            awarded_at  : $a.awarded_at
          }
        }
      }
    }
  }

  response = {
    trophies: $out
  }
  guid = "IH4395WI8iNjLAswc9YEN72h5og"
}

// Awards trophies for a just-completed tournament's top 3 in both the
// bracket and pick'em contests. For each (context_type, placement) with a
// real winner: look up trophy_template for (tournament_name, placement); if
// none exists yet, generate one on the fly (cached for every future year of
// this same tournament name) via design_trophy_image. Then copies the
// template's image straight onto a new trophy_award row per recipient - no
// generation at award time for the tournament track (only the league track
// personalizes per-recipient). Never throws per placement - a trophy
// failure must not block tournament completion, which is why this is
// called from inside a try_catch per placement, not a single wrapping one.
function award_tournament_trophies {
  input {
    int tournament_id
    text tournament_name filters=trim
  }

  stack {
    var $is_marquee_name { value = $input.tournament_name|icontains:"NCAA" }

    var $awarded_count { value = 0 }
    var $template_created_count { value = 0 }
    var $errors { value = [] }

    var $contexts { value = ["tournament_bracket", "tournament_pickem"] }

    foreach ($contexts) {
      each as $context_type {
        var $placements { value = [1, 2, 3] }

        foreach ($placements) {
          each as $placement {
            try_catch {
              try {
                var $recipient_user_id { value = null }

                conditional {
                  if ($context_type == "tournament_bracket") {
                    db.query user_bracket {
                      where = $db.user_bracket.tournament_id == $input.tournament_id && $db.user_bracket.rank == $placement
                      return = {type: "single"}
                    } as $bracket_winner

                    conditional {
                      if ($bracket_winner != null) {
                        var.update $recipient_user_id { value = $bracket_winner.user_id }
                      }
                    }
                  }
                  else {
                    db.query pickem_entry {
                      where = $db.pickem_entry.tournament_id == $input.tournament_id && $db.pickem_entry.rank == $placement
                      return = {type: "single"}
                    } as $pickem_winner

                    conditional {
                      if ($pickem_winner != null) {
                        var.update $recipient_user_id { value = $pickem_winner.user_id }
                      }
                    }
                  }
                }

                conditional {
                  if ($recipient_user_id != null) {
                    db.query trophy_template {
                      where = $db.trophy_template.scope == "tournament" && $db.trophy_template.tournament_name == $input.tournament_name && $db.trophy_template.placement == $placement
                      return = {type: "single"}
                    } as $template

                    conditional {
                      if ($template == null || $template.generation_status != "ready") {
                        var $design_inputs { value = {style: "classic", material: "gold", color: "gold and black", pillar: "tapered column"} }

                        function.run design_trophy_image {
                          input = {design_inputs: $design_inputs, placement: $placement, is_marquee: $is_marquee_name}
                        } as $generated

                        conditional {
                          if ($generated.generation_status == "ready") {
                            db.add_or_edit trophy_template {
                              field_name = "id"
                              field_value = ($template != null ? $template.id : 0)
                              data = {
                                updated_at        : now
                                scope             : "tournament"
                                tournament_name   : $input.tournament_name
                                is_marquee        : $is_marquee_name
                                placement         : $placement
                                image_url         : $generated.image_url
                                generation_prompt : $generated.prompt_used
                                openai_response_id: $generated.response_id
                                generation_status : "ready"
                                design_inputs      : $design_inputs
                              }
                            } as $new_template

                            var.update $template { value = $new_template }

                            math.add $template_created_count { value = 1 }
                          }
                        }
                      }
                    }

                    conditional {
                      if ($template != null && $template.generation_status == "ready") {
                        db.query trophy_award {
                          where = $db.trophy_award.recipient_user_id == $recipient_user_id && $db.trophy_award.context_type == $context_type && $db.trophy_award.context_id == $input.tournament_id && $db.trophy_award.placement == $placement
                          return = {type: "single"}
                        } as $existing_award

                        var $existing_award_id { value = ($existing_award != null ? $existing_award.id : 0) }

                        db.add_or_edit trophy_award {
                          field_name = "id"
                          field_value = $existing_award_id
                          data = {
                            recipient_user_id: $recipient_user_id
                            context_type     : $context_type
                            context_id       : $input.tournament_id
                            placement        : $placement
                            template_id      : $template.id
                            image_url        : $template.image_url
                            seen             : false
                          }
                        } as $award

                        math.add $awarded_count { value = 1 }
                      }
                    }
                  }
                }
              }

              catch {
                array.push $errors {
                  value = {context_type: $context_type, placement: $placement, error: $error.message}
                }
              }
            }
          }
        }
      }
    }
  }

  response = {
    awarded          : $awarded_count
    templates_created: $template_created_count
    errors           : $errors
  }
  guid = "RKjpF_dFdhqBFen7FIMOIqzUeBI"
}

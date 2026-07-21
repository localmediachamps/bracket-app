// Shared wrapper around util.send_email (Resend) so every transactional
// email (verify, password reset, invites, etc.) shares one branded look
// instead of each caller hand-rolling HTML. Requires two workspace env
// vars to actually deliver: `resend_APIKey` (already set) and
// `resend_from_email` (e.g. "Mat Savvy <noreply@yourdomain.com>" - must be
// a domain verified in Resend) and `frontend_url` (e.g.
// "https://app.matsavvy.com", no trailing slash) for building links.
function send_transactional_email {
  input {
    email to filters=trim|lower
    text subject filters=trim|min:1
    text heading filters=trim|min:1
    text body_html filters=min:1 {
      description = "Inner HTML for the email body - short paragraphs, no need for a wrapping <div>."
    }
    text? cta_label? filters=trim
    text? cta_url? filters=trim
  }

  stack {
    var $cta_html {
      value = ""
    }

    conditional {
      if ($input.cta_url != null && $input.cta_label != null) {
        var.update $cta_html {
          value = "<p style=\"margin:28px 0;\"><a href=\"" ~ $input.cta_url ~ "\" style=\"background:#eab308;color:#0a0908;font-weight:700;text-decoration:none;padding:12px 24px;border-radius:10px;display:inline-block;font-family:Arial,sans-serif;\">" ~ $input.cta_label ~ "</a></p>"
        }
      }
    }

    var $html {
      value = "<div style=\"font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:32px 24px;background:#ffffff;\"><h1 style=\"font-size:20px;color:#0a0908;margin:0 0 16px;\">" ~ $input.heading ~ "</h1><div style=\"font-size:15px;color:#333333;line-height:1.6;\">" ~ $input.body_html ~ "</div>" ~ $cta_html ~ "<p style=\"margin-top:32px;font-size:12px;color:#999999;\">Mat Savvy</p></div>"
    }

    util.send_email {
      service_provider = "resend"
      api_key = $env.resend_APIKey
      to = $input.to
      from = $env.resend_from_email
      subject = $input.subject
      message = $html
    } as $result
  }

  response = $result
  guid = "UJOeIT5n4-kma3sc6zTftWGAezQ"
}

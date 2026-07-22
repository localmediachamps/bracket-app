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
    var $logo_url {
      value = $env.frontend_url ~ "/branding/mat_savvy_logo_dark_landscape.png"
    }

    var $cta_html {
      value = ""
    }

    conditional {
      if ($input.cta_url != null && $input.cta_label != null) {
        var.update $cta_html {
          value = "<table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"margin:32px auto 8px;\"><tr><td style=\"border-radius:10px;background-color:#eab308;\"><a href=\"" ~ $input.cta_url ~ "\" style=\"display:inline-block;padding:14px 32px;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:700;color:#0a0908;text-decoration:none;letter-spacing:0.02em;\">" ~ $input.cta_label ~ "</a></td></tr></table>"
        }
      }
    }

    // Email-safe inline HTML only (no external stylesheet, no flex/grid) -
    // a centered white card on a light-gray backdrop, dark wordmark in the
    // header, gold accent rule + CTA button matching the app's own brand
    // (mat-950 near-black / gold-500 #eab308), system-font stack since
    // custom display fonts aren't reliably supported by mail clients.
    var $html {
      value = "<div style=\"background-color:#f4f4f5;padding:32px 16px;font-family:Arial,Helvetica,sans-serif;\"><table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\" style=\"max-width:480px;margin:0 auto;background-color:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e4e4e7;\"><tr><td style=\"background-color:#0a0908;padding:28px 32px;text-align:center;\"><img src=\"" ~ $logo_url ~ "\" alt=\"Mat Savvy\" height=\"28\" style=\"height:28px;width:auto;border:0;display:inline-block;\" /></td></tr><tr><td style=\"height:4px;background-color:#eab308;line-height:4px;font-size:0;\">&nbsp;</td></tr><tr><td style=\"padding:36px 32px 8px;text-align:center;\"><h1 style=\"margin:0 0 16px;font-size:21px;line-height:1.3;color:#0a0908;font-weight:800;\">" ~ $input.heading ~ "</h1><div style=\"font-size:15px;line-height:1.6;color:#3f3f46;text-align:left;\">" ~ $input.body_html ~ "</div>" ~ $cta_html ~ "</td></tr><tr><td style=\"padding:24px 32px 32px;text-align:center;border-top:1px solid #f0f0f1;margin-top:8px;\"><p style=\"margin:24px 0 0;font-size:11px;color:#a1a1aa;font-family:Arial,Helvetica,sans-serif;letter-spacing:0.04em;text-transform:uppercase;\">Mat Savvy &middot; Built for wrestling fans</p></td></tr></table></div>"
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

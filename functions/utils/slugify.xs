// Converts arbitrary text into a lowercase url-safe slug.
// Keeps [a-z0-9], collapses every run of other characters to a single dash,
// and trims leading/trailing dashes.
// Example: "NCAA DI Wrestling 2026!" -> "ncaa-di-wrestling-2026"
// Convert text to a lowercase url-safe slug (a-z0-9 and dashes)
function slugify {
  input {
    // Raw text to slugify
    text text filters=trim
  }

  stack {
    // Normalize case, strip accents, drop surrounding whitespace
    var $slug {
      value = $input.text
        |to_lower
        |unaccent
        |trim
    }
  
    // Replace every run of non [a-z0-9] characters with a single dash
    var.update $slug {
      value = "/[^a-z0-9]+/"|regex_replace:"-":$slug
    }
  
    // Trim leading and trailing dashes
    var.update $slug {
      value = $slug|trim:"-"
    }
  }

  response = $slug
}
// Generates an 8-character Crockford base32 invite code.
// Charset excludes I, L, O, U to avoid visual ambiguity.
// Callers must check uniqueness against fantasy_group.invite_code and retry on collision.
// Generate an 8-char Crockford base32 invite code
function invite_code {
  input {
  }

  stack {
    // Crockford base32 alphabet (no I, L, O, U)
    var $charset {
      value = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    }
  
    var $code {
      value = ""
    }
  
    // Pick 8 random characters from the 32-char alphabet
    for (8) {
      each as $i {
        security.random_number {
          min = 0
          max = 31
        } as $idx
      
        var $ch {
          value = $charset|substr:$idx:1
        }
      
        var.update $code {
          value = $code ~ $ch
        }
      }
    }
  }

  response = $code
  guid = "uvkgTa81OiQ8WgpOIrggpSp5b-I"
}
// Increments one key of a {season_label: count} map by 1, defaulting the key
// to 0 first if absent. Used to accumulate a single counter across many
// object|set: calls - confirmed via direct testing 2026-07-22 that an object
// with MULTIPLE sibling keys, where different iterations touch different
// subsets of those keys via separate |set: calls, can silently drop a
// sibling key that a later iteration never explicitly re-touches (e.g. a
// win/loss breakdown record's "losses" key vanishing after several
// wins-only iterations). Keeping each counter in its OWN single-purpose map
// (one key type per map, like this one) avoids that failure mode entirely -
// every call here only ever touches the one key it's given.
function bump_season_map {
  input {
    json map
    text season_label
  }

  stack {
    var $prev { value = 0 }

    conditional {
      if ($input.map|has:$input.season_label) {
        var.update $prev { value = $input.map[$input.season_label] }
      }
    }

    var $updated {
      value = $input.map|set:$input.season_label:($prev + 1)
    }
  }

  response = $updated
  guid = "H7mQtXs3LbNy5RwZoJd8KcVa2Uf6"
}

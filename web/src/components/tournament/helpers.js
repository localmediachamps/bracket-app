/**
 * Shared normalization helpers for the public-facing tournament pages.
 *
 * The Xano endpoints documented in docs/build/ARCHITECTURE.md §6 return either
 * plain arrays or Xano paginated envelopes ({items, totalItems, curPage,
 * pageTotal, perPage}). These helpers make the UI agnostic to both, and
 * tolerate small field-name variations in nested payloads.
 */

/* ── List / pagination ────────────────────────────────── */
export function normalizeList(data) {
  if (Array.isArray(data)) {
    return { items: data, total: data.length, page: 1, totalPages: 1, per: data.length || 25 }
  }
  const items = data?.items ?? data?.results ?? (Array.isArray(data?.data) ? data.data : []) ?? []
  const total = data?.totalItems ?? data?.total ?? data?.total_items ?? data?.count ?? items.length
  const page = data?.curPage ?? data?.page ?? 1
  const per = data?.perPage ?? data?.per ?? (items.length || 25)
  const totalPages =
    data?.pageTotal ?? data?.totalPages ?? data?.total_pages ?? Math.max(1, Math.ceil((total || items.length || 1) / (per || 25)))
  return { items, total, page, totalPages, per }
}

/* ── Users ────────────────────────────────────────────── */
export function displayName(user) {
  return user?.display_name || user?.name || user?.username || 'Anonymous'
}

/* ── Game modes (json may arrive as a string) ─────────── */
export function asModes(gameModes) {
  let m = gameModes
  if (typeof m === 'string') {
    try {
      m = JSON.parse(m)
    } catch {
      m = []
    }
  }
  return Array.isArray(m) && m.length ? m : ['bracket', 'pickem']
}

/* ── Percent values: accept 0–1 fractions or 0–100 ────── */
export function percentOf(value) {
  if (value === null || value === undefined || isNaN(value)) return null
  const v = +value
  return v <= 1 ? v * 100 : v
}

/* ── Pick-popularity: match sides ─────────────────────── */
export function matchSides(m) {
  const raw = m?.competitors ?? m?.picks ?? m?.slots
  if (Array.isArray(raw) && raw.length >= 2) {
    return raw.slice(0, 2).map((c) => ({
      name: c.name ?? c.wrestler_name ?? 'TBD',
      school: c.school,
      seed: c.seed,
      pct: percentOf(c.pct ?? c.percentage ?? c.percent),
    }))
  }
  return ['top', 'bottom'].map((key) => {
    const s = m?.[key]
    if (s && typeof s === 'object') {
      return {
        name: s.name ?? s.wrestler_name ?? s.competitor?.name ?? 'TBD',
        school: s.school ?? s.competitor?.school,
        seed: s.seed ?? s.competitor?.seed,
        pct: percentOf(s.pct ?? s.percentage ?? s.percent ?? m?.[`${key}_pct`]),
      }
    }
    return {
      name: m?.[`${key}_name`] ?? 'TBD',
      school: m?.[`${key}_school`],
      seed: m?.[`${key}_seed`],
      pct: percentOf(m?.[`${key}_pct`] ?? m?.[`${key}_percentage`]),
    }
  })
}

/* ── Pick-popularity: champion picks per weight ───────── */
export function championPicks(group) {
  const picks = group?.picks ?? group?.competitors ?? group?.wrestlers ?? []
  return picks
    .map((p) => ({
      id: p.wrestler_id ?? p.id,
      name: p.name ?? p.wrestler_name ?? 'Unknown',
      school: p.school,
      seed: p.seed,
      count: p.count ?? p.pick_count ?? 0,
      pct: percentOf(p.pct ?? p.percentage ?? p.percent) ?? 0,
    }))
    .sort((a, b) => b.pct - a.pct)
}

/* ── Results feed: winner/loser from loose match shape ── */
function asComp(obj) {
  if (!obj || typeof obj !== 'object') return null
  const name = obj.name ?? obj.wrestler_name
  if (!name) return null
  return { id: obj.id ?? obj.wrestler_id, name, school: obj.school, seed: obj.seed }
}

export function resultSides(m) {
  const top = asComp(m?.top?.competitor) ?? asComp(m?.top)
  const bottom = asComp(m?.bottom?.competitor) ?? asComp(m?.bottom)
  const winnerId = m?.winner_competitor_id ?? m?.winner_wrestler_id ?? m?.winner?.id ?? m?.winner?.wrestler_id
  let winner = asComp(m?.winner)
  let loser = asComp(m?.loser)
  if (!winner && winnerId != null && (top || bottom)) {
    winner = winnerId === top?.id ? top : winnerId === bottom?.id ? bottom : null
    loser = loser ?? (winnerId === top?.id ? bottom : winnerId === bottom?.id ? top : null)
  }
  if (!winner && m?.winner_name) winner = { name: m.winner_name, school: m.winner_school, seed: m.winner_seed }
  if (!loser && m?.loser_name) loser = { name: m.loser_name, school: m.loser_school, seed: m.loser_seed }
  return { winner, loser }
}

/**
 * bracketMath — pure functions that turn the server match graph into a 2D layout
 * and resolve user picks through the graph. No React in here.
 */

export const METRICS = {
  MATCH_W: 236,
  MATCH_H: 78,
  COL_GAP: 60,
  ROW_GAP: 20,
  BAND_GAP: 96,
  HEADER_H: 52,
  PAD: 24,
}

/* ── Banding ──────────────────────────────────────────── */
export function splitBands(matches) {
  const champ = [], cons = [], place = []
  for (const m of matches) {
    if (m.section === 'championship') champ.push(m)
    else if (m.section === 'placement') place.push(m)
    else cons.push(m)
  }
  return { champ, cons, place }
}

function byRound(matches) {
  const map = new Map()
  for (const m of matches) {
    const r = m.round_number ?? 0
    if (!map.has(r)) map.set(r, [])
    map.get(r).push(m)
  }
  return [...map.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([round, list]) => ({ round, list: list.sort((a, b) => a.match_number - b.match_number) }))
}

/** collision-resolve a column: targets → enforced min gaps, order-preserving */
function resolveColumn(items, pitch) {
  // items: [{id, target}] sorted by target
  let last = -Infinity
  const out = new Map()
  for (const it of items) {
    const y = Math.max(it.target, last + pitch)
    out.set(it.id, y)
    last = y
  }
  return out
}

/**
 * Compute layout: Map(matchId → {x, y}) + meta for headers/bands/canvas size.
 * y is the TOP of the match card.
 */
export function layoutBracket(matches) {
  const { MATCH_W, MATCH_H, COL_GAP, ROW_GAP, BAND_GAP, HEADER_H, PAD } = METRICS
  const { champ, cons, place } = splitBands(matches)
  const pos = new Map()
  const pitch = MATCH_H + ROW_GAP
  const colW = MATCH_W + COL_GAP
  const columns = [] // [{key, label, x, band}]
  const byId = new Map(matches.map((m) => [m.id, m]))

  /* ── Championship band ── */
  const champRounds = byRound(champ)
  let maxY = 0
  champRounds.forEach(({ round, list }, colIdx) => {
    const x = PAD + colIdx * colW
    columns.push({ key: `c${round}`, x, band: 'championship', matches: list.length, round })
    if (colIdx === 0) {
      list.forEach((m, i) => {
        pos.set(m.id, { x, y: HEADER_H + PAD + i * pitch, col: colIdx, band: 'championship' })
      })
    } else {
      const items = list.map((m) => {
        const srcs = slotSourceIds(m)
        const ys = srcs.map((id) => pos.get(id)?.y).filter((v) => v !== undefined)
        const target = ys.length ? avg(ys) : HEADER_H + PAD + m.match_number * pitch
        return { id: m.id, target }
      }).sort((a, b) => a.target - b.target)
      const ys = resolveColumn(items, pitch)
      for (const m of list) pos.set(m.id, { x, y: ys.get(m.id), col: colIdx, band: 'championship' })
    }
  })
  const champBottom = Math.max(0, ...[...pos.values()].map((p) => p.y + MATCH_H))
  maxY = champBottom

  /* ── Placement column (right of championship) ── */
  if (place.length) {
    const colIdx = champRounds.length
    const x = PAD + colIdx * colW
    columns.push({ key: 'place', x, band: 'placement', matches: place.length })
    const items = place.map((m) => {
      const srcs = slotSourceIds(m)
      const ys = srcs.map((id) => pos.get(id)?.y).filter((v) => v !== undefined)
      const fallback = HEADER_H + PAD + (place.indexOf(m)) * pitch * 2
      return { id: m.id, target: ys.length ? avg(ys) : fallback }
    }).sort((a, b) => a.target - b.target)
    const ys = resolveColumn(items, pitch * 1.6)
    for (const m of place) pos.set(m.id, { x, y: ys.get(m.id), col: colIdx, band: 'placement' })
    maxY = Math.max(maxY, ...place.map((m) => pos.get(m.id).y + MATCH_H))
  }

  /* ── Consolation band (mirrors championship vertical spread) ── */
  const consRounds = byRound(cons)
  const bandTop = maxY + BAND_GAP
  if (consRounds.length) {
    consRounds.forEach(({ round, list }, colIdx) => {
      const x = PAD + colIdx * colW
      columns.push({ key: `k${round}`, x, band: 'consolation', matches: list.length, round })
      const items = list.map((m) => {
        const srcs = slotSourceIds(m)
        const ys = srcs
          .map((id) => pos.get(id))
          .filter(Boolean)
          .map((p) => (p.band === 'championship' ? p.y : bandTop + HEADER_H))
        const spread = champBottom - HEADER_H - PAD || 1
        const target = ys.length
          ? bandTop + HEADER_H + Math.min(avg(ys) - HEADER_H - PAD, spread)
          : bandTop + HEADER_H + m.match_number * pitch
        return { id: m.id, target }
      }).sort((a, b) => a.target - b.target)
      const ys = resolveColumn(items, pitch)
      for (const m of list) pos.set(m.id, { x, y: ys.get(m.id), col: colIdx, band: 'consolation' })
    })
    maxY = Math.max(maxY, ...cons.flatMap((m) => [pos.get(m.id)?.y ?? 0]).map((y) => y + MATCH_H))
  }

  const maxCol = Math.max(champRounds.length + (place.length ? 1 : 0), consRounds.length)
  return {
    pos,
    columns,
    byId,
    width: PAD * 2 + maxCol * colW - COL_GAP,
    height: maxY + PAD + 40,
    consBandTop: consRounds.length ? bandTop : null,
  }
}

function avg(nums) {
  return nums.reduce((a, b) => a + b, 0) / nums.length
}

/** ids of matches whose outcomes feed this match's slots */
export function slotSourceIds(match) {
  const ids = []
  if (match.top?.source?.match_id) ids.push(match.top.source.match_id)
  if (match.bottom?.source?.match_id) ids.push(match.bottom.source.match_id)
  return ids
}

/* ── Connector paths ──────────────────────────────────── */
export function connectorPath(srcPos, dstPos, slot) {
  const { MATCH_W, MATCH_H } = METRICS
  const sx = srcPos.x + MATCH_W
  const sy = srcPos.y + MATCH_H / 2
  const dx = dstPos.x
  const dy = dstPos.y + (slot === 'bottom' ? MATCH_H * 0.74 : MATCH_H * 0.26)
  const midX = sx + (dx - sx) / 2
  return {
    d: `M ${sx} ${sy} L ${midX} ${sy} L ${midX} ${dy} L ${dx} ${dy}`,
    key: `${sx}-${sy}-${dx}-${dy}`,
  }
}

/* ── Pick resolution (predict mode) ───────────────────── */
/**
 * Given matches and a picks Map(matchId → wrestlerId), resolve every slot's
 * displayed competitor. A slot resolves to:
 *  - seed source → that competitor (from the slot's own competitor data)
 *  - match_winner source → the user's pick on the source match
 *  - match_loser source → the OTHER resolved participant of the source match
 * Invalid picks (wrestler no longer in the match) are collected in `cleared`.
 * Runs a bounded fixpoint since picks cascade.
 */
export function resolvePicks(matches, picks, competitorsById) {
  const byId = new Map(matches.map((m) => [m.id, m]))
  const resolved = new Map() // matchId → {top: comp|null, bottom: comp|null}
  const cleared = []

  // topological-ish order: champ rounds asc, then consolation, then placement
  const ordered = [...matches].sort((a, b) => {
    const band = (m) => (m.section === 'championship' ? 0 : m.section === 'placement' ? 2 : 1)
    return band(a) - band(b) || (a.round_number ?? 0) - (b.round_number ?? 0) || a.match_number - b.match_number
  })

  const getComp = (id) => (id ? competitorsById.get(id) ?? { id, name: 'TBD', unknown: true } : null)

  for (let pass = 0; pass < 6; pass++) {
    let changed = false
    for (const m of ordered) {
      const prev = resolved.get(m.id)
      const next = { top: resolveSlot(m, 'top', picks, resolved, byId, getComp), bottom: resolveSlot(m, 'bottom', picks, resolved, byId, getComp) }
      if (!prev || prev.top?.id !== next.top?.id || prev.bottom?.id !== next.bottom?.id) {
        resolved.set(m.id, next)
        changed = true
      }
    }
    if (!changed) break
  }

  // validate picks against resolved participants
  const validPicks = new Map()
  for (const [matchId, wrestlerId] of picks) {
    const m = byId.get(matchId)
    if (!m) { cleared.push(matchId); continue }
    if (m.is_bye) { cleared.push(matchId); continue }
    const r = resolved.get(matchId)
    const ids = [r?.top?.id, r?.bottom?.id].filter(Boolean)
    if (ids.includes(wrestlerId)) validPicks.set(matchId, wrestlerId)
    else cleared.push(matchId)
  }
  return { resolved, validPicks, cleared }
}

function resolveSlot(match, slot, picks, resolved, byId, getComp) {
  const s = match[slot]?.source
  if (!s) return null
  if (s.type === 'seed') {
    return match[slot]?.competitor ?? null
  }
  const srcId = s.match_id
  if (!srcId) return null
  const srcMatch = byId.get(srcId)
  if (!srcMatch) return null
  const pick = picks.get(srcId)
  const srcResolved = resolved.get(srcId)
  if (s.type === 'match_winner') {
    return pick ? getComp(pick) : null
  }
  // match_loser: the non-picked participant of the source match
  if (!pick || !srcResolved) return null
  const other = [srcResolved.top, srcResolved.bottom].find((c) => c && c.id !== pick)
  return other ?? null
}

/** Build "Winner/Loser of M12" fallback labels for unresolved slots */
export function slotFallbackLabel(match, slot) {
  const s = match[slot]?.source
  if (!s) return 'TBD'
  if (s.type === 'seed') return 'TBD'
  const what = s.type === 'match_winner' ? 'Winner' : 'Loser'
  return `${what} of #${matchLabel(s.match_id, match)}`
}

function matchLabel(id, contextMatch) {
  // placeholder; BracketView supplies richer labels via map
  return id
}

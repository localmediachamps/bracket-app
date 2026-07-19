/**
 * Shared helpers for the admin area.
 */
import { formatDate } from '../../lib/utils'

/* ── Bracket templates ────────────────────────────────── */
export const TEMPLATES = [
  { value: 'ncaa_33', label: 'NCAA 33 — 61 matches, full consolation' },
  { value: 'field_64', label: 'Field of 64' },
  { value: 'field_32', label: 'Field of 32' },
  { value: 'field_16', label: 'Field of 16' },
  { value: 'field_8', label: 'Field of 8' },
]

export function templateLabel(value) {
  return TEMPLATES.find((t) => t.value === value)?.label ?? value ?? '—'
}

/* ── Time ─────────────────────────────────────────────── */
export function timeAgo(d) {
  if (!d) return '—'
  const t = new Date(d).getTime()
  if (isNaN(t)) return String(d)
  const diff = Date.now() - t
  if (diff < 45000) return 'just now'
  const m = Math.floor(diff / 60000)
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  const days = Math.floor(h / 24)
  if (days < 7) return `${days}d ago`
  return formatDate(d)
}

/** datetime-local input value → ISO string (undefined when empty/invalid) */
export function toIso(local) {
  if (!local) return undefined
  const d = new Date(local)
  return isNaN(d.getTime()) ? undefined : d.toISOString()
}

/* ── Errors ───────────────────────────────────────────── */
export function errMsg(e, fallback = 'Something went wrong') {
  return e?.payload?.message || e?.message || fallback
}

export function isDownstreamConflict(e) {
  if (e?.status !== 409) return false
  const msg = String(e?.payload?.message || e?.message || '')
  return !!e?.payload?.conflict || /downstream/i.test(msg)
}

/* ── Download ─────────────────────────────────────────── */
export function downloadJson(data, filename) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1500)
}

/* ── Competitor quick-paste parsing ───────────────────── */
const RECORD_RE = /^\d+-\d+(-\d+)?$/

let rowSeq = 0
export const nextKey = () => `r${++rowSeq}`

/**
 * Parse pasted lines like `1 Spencer Lee Penn State` or `1 Spencer Lee Penn State 24-0`.
 * Heuristic: first token = seed; trailing W-L token = record; with 3+ remaining
 * tokens the first two are the name and the rest is the school.
 */
export function parseCompetitorLines(text) {
  const rows = []
  for (const raw of String(text || '').split(/\r?\n/)) {
    const line = raw.trim()
    if (!line) continue
    const tokens = line.split(/\s+/)
    const seedNum = parseInt(tokens[0], 10)
    if (isNaN(seedNum)) {
      rows.push({ key: nextKey(), seed: '', name: line, school: '', record: '', _parseError: 'Line must start with a seed number' })
      continue
    }
    const rest = tokens.slice(1)
    let record = ''
    if (rest.length && RECORD_RE.test(rest[rest.length - 1])) record = rest.pop()
    let name = ''
    let school = ''
    if (rest.length >= 3) {
      name = rest.slice(0, 2).join(' ')
      school = rest.slice(2).join(' ')
    } else {
      name = rest.join(' ')
    }
    rows.push({ key: nextKey(), seed: String(seedNum), name, school, record })
  }
  return rows
}

/**
 * Validate a competitor list.
 * Returns [{level:'error'|'warn', rowIndex?, seed?, message}].
 * Errors (blood): dup seeds, invalid seed, missing name, <2 wrestlers.
 * Warnings (gold): seed gaps, missing school/record.
 */
export function validateCompetitors(rows) {
  const issues = []
  const seen = new Map()
  rows.forEach((r, i) => {
    const s = Number(r.seed)
    if (r._parseError) issues.push({ level: 'error', rowIndex: i, message: r._parseError })
    if (r.seed === '' || r.seed === null || r.seed === undefined || isNaN(s)) {
      issues.push({ level: 'error', rowIndex: i, message: 'Missing or invalid seed' })
    } else if (seen.has(s)) {
      issues.push({ level: 'error', rowIndex: i, seed: s, message: `Duplicate seed ${s}` })
    } else {
      seen.set(s, i)
    }
    if (!String(r.name || '').trim()) issues.push({ level: 'error', rowIndex: i, seed: r.seed, message: 'Missing name' })
    if (!String(r.school || '').trim()) issues.push({ level: 'warn', rowIndex: i, seed: r.seed, message: `Seed ${r.seed || '?'}: missing school` })
  })
  const seeds = [...seen.keys()].sort((a, b) => a - b)
  if (seeds.length > 0) {
    if (seeds[0] !== 1) issues.push({ level: 'warn', seed: seeds[0], message: `Seeding starts at ${seeds[0]} — expected seed 1` })
    for (let n = seeds[0]; n <= seeds[seeds.length - 1]; n++) {
      if (!seen.has(n)) issues.push({ level: 'warn', seed: n, message: `Seed ${n} is missing (gap)` })
    }
  }
  if (rows.length > 0 && rows.length < 2) issues.push({ level: 'error', message: 'Need at least 2 wrestlers to build a bracket' })
  return issues
}

/** Map rowIndex → worst level ('error' beats 'warn') for row tinting. */
export function rowIssueLevels(issues) {
  const map = new Map()
  for (const it of issues) {
    if (it.rowIndex === undefined) continue
    const cur = map.get(it.rowIndex)
    if (cur !== 'error') map.set(it.rowIndex, it.level)
  }
  return map
}

export function stripRow(row) {
  return {
    seed: Number(row.seed),
    name: String(row.name || '').trim(),
    school: String(row.school || '').trim(),
    record: String(row.record || '').trim() || undefined,
    ...(row.withdrawn ? { withdrawn: true } : {}),
  }
}

/* ── Uploaded-document normalization ──────────────────── */
/**
 * Tolerate contract variants: extraction_result.weights | .parsed,
 * tournament meta under .tournament or top-level.
 */
export function normalizeDocument(doc) {
  const ex = doc?.extraction_result ?? doc?.extraction ?? {}
  const weightsRaw = ex.weights ?? ex.parsed ?? []
  const metaSrc = ex.tournament ?? ex.meta ?? ex
  const meta = {
    name: metaSrc?.name ?? metaSrc?.tournament_name ?? '',
    year: metaSrc?.year ?? '',
    location: metaSrc?.location ?? '',
    date: metaSrc?.date ?? metaSrc?.start_date ?? '',
  }
  const weights = weightsRaw.map((w, i) => ({
    key: nextKey(),
    weight: w.weight ?? '',
    template: 'ncaa_33',
    competitors: (w.wrestlers ?? w.competitors ?? []).map((c) => ({
      key: nextKey(),
      seed: c.seed ?? '',
      name: c.name ?? '',
      school: c.school ?? '',
      record: c.record ?? '',
    })),
  }))
  const serverIssues = doc?.issues ?? doc?.validation_issues ?? []
  return { meta, weights, serverIssues, status: doc?.processing_status ?? 'needs_review', id: doc?.id ?? doc?.document_id, fileName: doc?.file_name }
}

/* ── Scoring defaults & presets ───────────────────────── */
export const TIEBREAKER_LABELS = {
  total_points: 'Total points',
  champions_correct: 'Champions correct',
  finalists_correct: 'Finalists correct',
  earliest_submission: 'Earliest submission',
}

export function defaultScoringConfig() {
  return {
    version: 1,
    bracket: {
      pigtail: 1,
      championship: { 1: 1, 2: 2, 3: 4, 4: 8, 5: 16, 6: 16 },
      consolation: { 1: 1, 2: 1, 3: 2, 4: 2, 5: 4, 6: 4, 7: 4, 8: 4 },
      placement: { place_3: 4, place_5: 2, place_7: 2 },
      champion_bonus: 0,
    },
    tiebreakers: ['total_points', 'champions_correct', 'finalists_correct', 'earliest_submission'],
  }
}

export const SCORING_PRESETS = [
  {
    key: 'ncaa',
    label: 'NCAA Standard',
    blurb: 'Classic escalation — 1/2/4/8/16 with rewarded consolation run.',
    config: defaultScoringConfig().bracket,
  },
  {
    key: 'madness',
    label: 'March Madness-ish',
    blurb: 'Late rounds weigh heavy — 1/2/4/8/16/32, thin consolation.',
    config: {
      pigtail: 1,
      championship: { 1: 1, 2: 2, 3: 4, 4: 8, 5: 16, 6: 32 },
      consolation: { 1: 0, 2: 0, 3: 1, 4: 1, 5: 2, 6: 2, 7: 2, 8: 2 },
      placement: { place_3: 2, place_5: 1, place_7: 1 },
      champion_bonus: 0,
    },
  },
  {
    key: 'flat',
    label: 'Flat',
    blurb: 'Every match worth 1 — volume picking wins.',
    config: {
      pigtail: 1,
      championship: { 1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1 },
      consolation: { 1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1 },
      placement: { place_3: 1, place_5: 1, place_7: 1 },
      champion_bonus: 0,
    },
  },
]

export function defaultPickemConfig() {
  return {
    budget: 1000,
    seed_costs: { 1: 200, 2: 160, 3: 140, 4: 120, 5: 100, 6: 90, 7: 80, 8: 70, 9: 60, 10: 50, 11: 40, 12: 30, 13: 20, 14: 20, 15: 20, 16: 20, default: 10 },
    tiebreakers: [
      { key: 'tiebreaker_1', label: 'Tiebreaker 1', hint: 'Points by 1st/2nd/3rd place teams in your group' },
      { key: 'tiebreaker_2', label: 'Tiebreaker 2', hint: '' },
      { key: 'tiebreaker_3', label: 'Tiebreaker 3', hint: '' },
    ],
    scoring: {
      placement_points: { 1: 16, 2: 12, 3: 10, 4: 9, 5: 8, 6: 7, 7: 6, 8: 5 },
      win_points: { championship: 1, consolation: 0.5 },
      bonus_points: { fall: 2, tech_fall: 1.5, major: 1 },
    },
  }
}

/** Normalize a scoring-config GET response into the editable shape. */
export function normalizeScoringConfig(data) {
  const src = data?.bracket ? data : data?.scoring_config?.bracket ? data.scoring_config : null
  const base = defaultScoringConfig()
  if (!src) return base
  const b = src.bracket ?? {}
  return {
    version: src.version ?? 1,
    bracket: {
      pigtail: b.pigtail ?? base.bracket.pigtail,
      championship: { ...base.bracket.championship, ...(b.championship ?? {}) },
      consolation: { ...base.bracket.consolation, ...(b.consolation ?? {}) },
      placement: { ...base.bracket.placement, ...(b.placement ?? {}) },
      champion_bonus: b.champion_bonus ?? 0,
    },
    tiebreakers: Array.isArray(src.tiebreakers) && src.tiebreakers.length ? [...src.tiebreakers] : base.tiebreakers,
  }
}

export function normalizePickemConfig(data) {
  const src = data?.budget != null ? data : data?.pickem_config?.budget != null ? data.pickem_config : null
  const base = defaultPickemConfig()
  if (!src) return base
  return {
    budget: src.budget ?? base.budget,
    seed_costs: { ...base.seed_costs, ...(src.seed_costs ?? {}) },
    tiebreakers: base.tiebreakers.map((t, i) => ({ ...t, ...(src.tiebreakers?.[i] ?? {}) })),
    scoring: {
      placement_points: { ...base.scoring.placement_points, ...(src.scoring?.placement_points ?? {}) },
      win_points: { ...base.scoring.win_points, ...(src.scoring?.win_points ?? {}) },
      bonus_points: { ...base.scoring.bonus_points, ...(src.scoring?.bonus_points ?? {}) },
    },
  }
}

/* ── Misc ─────────────────────────────────────────────── */
export function actorLabel(row) {
  return (
    row?.actor?.display_name ||
    row?.actor?.name ||
    row?.actor?.username ||
    row?.actor_name ||
    row?.metadata?.actor_name ||
    (row?.actor_id ? `Admin #${row.actor_id}` : 'System')
  )
}

export const AUDIT_ENTITY_TYPES = ['tournament', 'bracket_match', 'user_bracket', 'fantasy_group', 'scoring']

export function auditActionColor(action = '') {
  const a = String(action).toLowerCase()
  if (/delete|cancel|clear|remove/.test(a)) return 'blood'
  if (/create|publish|add|confirm|generate|start/.test(a)) return 'pin'
  if (/update|edit|correct|rescore|lock|status|reopen|archive/.test(a)) return 'gold'
  return 'ink'
}

/** Shallow diff: keys whose JSON value differs between prev and next. */
export function changedKeys(prev, next) {
  const keys = new Set([...Object.keys(prev ?? {}), ...Object.keys(next ?? {})])
  const changed = new Set()
  for (const k of keys) {
    if (JSON.stringify(prev?.[k]) !== JSON.stringify(next?.[k])) changed.add(k)
  }
  return changed
}

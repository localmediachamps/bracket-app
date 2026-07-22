export function cn(...args) {
  return args.filter(Boolean).join(' ')
}

export function formatDate(d, opts = {}) {
  if (!d) return '—'
  const date = new Date(d)
  if (isNaN(date)) return String(d)
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: opts.year ?? 'numeric', ...opts })
}

export function formatDateTime(d) {
  if (!d) return '—'
  const date = new Date(d)
  if (isNaN(date)) return String(d)
  return date.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
}

export function timeUntil(d) {
  if (!d) return null
  const diff = new Date(d).getTime() - Date.now()
  if (diff <= 0) return { past: true, days: 0, hours: 0, minutes: 0 }
  const days = Math.floor(diff / 86400000)
  const hours = Math.floor((diff % 86400000) / 3600000)
  const minutes = Math.floor((diff % 3600000) / 60000)
  return { past: false, days, hours, minutes }
}

export function formatPoints(n) {
  if (n === null || n === undefined) return '0'
  return Number.isInteger(+n) ? String(+n) : (+n).toFixed(1)
}

export function pct(n, digits = 0) {
  if (n === null || n === undefined || isNaN(n)) return '0%'
  return `${(+n * 100).toFixed(digits)}%`
}

export const TOURNAMENT_STATUS = {
  draft: { label: 'Draft', color: 'ink' },
  importing: { label: 'Importing', color: 'ink' },
  needs_review: { label: 'Needs Review', color: 'gold' },
  open: { label: 'Open', color: 'pin' },
  locked: { label: 'Locked', color: 'gold' },
  live: { label: 'Live', color: 'blood', pulse: true },
  completed: { label: 'Completed', color: 'ink' },
  archived: { label: 'Archived', color: 'ink' },
  cancelled: { label: 'Cancelled', color: 'blood' },
}

export const VICTORY_TYPES = {
  decision: { label: 'DEC', name: 'Decision' },
  major: { label: 'MD', name: 'Major Decision' },
  tech_fall: { label: 'TF', name: 'Tech Fall' },
  fall: { label: 'F', name: 'Fall' },
  medical_forfeit: { label: 'MFF', name: 'Medical Forfeit' },
  injury_default: { label: 'INJ', name: 'Injury Default' },
  disqualification: { label: 'DQ', name: 'Disqualification' },
  forfeit: { label: 'FF', name: 'Forfeit' },
}

export function victoryLabel(v) {
  return VICTORY_TYPES[v]?.label ?? v ?? ''
}

// Real wrestler_match_history.victory_type values are raw scraped text
// ("Major Decision", "Sudden Victory - 1", "Medical FF w/Loss", ...), not the
// clean bracket_match enum VICTORY_TYPES above keys off of - classify by
// substring, checking specific finishes before generic ones (e.g. "Technical
// Fall" contains "fall", "Medical Forfeit" contains "forfeit").
export function classifyRawVictoryType(raw) {
  if (!raw) return null
  const s = raw.toLowerCase()
  if (s.includes('no contest')) return 'no_contest'
  if (s.includes('medical')) return 'medical_forfeit'
  if (s.includes('injury') || s.trim().startsWith('default')) return 'injury_default'
  if (s.includes('disqualif')) return 'disqualification'
  if (s.includes('sudden victory')) return 'sudden_victory'
  if (s.includes('tie breaker') || s.includes('tiebreaker')) return 'tie_breaker'
  if (s.includes('forfeit')) return 'forfeit'
  if (s.includes('technical')) return 'tech_fall'
  if (s.includes('major')) return 'major'
  if (s.includes('fall')) return 'fall'
  if (s.includes('decision')) return 'decision'
  return null
}

const RAW_VICTORY_LABEL = {
  decision: 'Dec',
  major: 'Major Dec.',
  tech_fall: 'Tech Fall',
  fall: 'Fall',
  medical_forfeit: 'Med FFT',
  injury_default: 'Injury Default',
  disqualification: 'DQ',
  forfeit: 'Forfeit',
  sudden_victory: 'OT',
  tie_breaker: 'TB',
  no_contest: 'No Contest',
}

const NUMBERED_RAW_TYPES = new Set(['sudden_victory', 'tie_breaker'])

// Short chip label for a raw scraped victory_type string. Falls back to the
// raw text itself if it doesn't match any known finish, so nothing is ever
// hidden - just possibly not shortened.
export function rawVictoryLabel(raw) {
  const key = classifyRawVictoryType(raw)
  if (!key) return raw || ''
  const base = RAW_VICTORY_LABEL[key]
  if (NUMBERED_RAW_TYPES.has(key)) {
    const n = /(\d+)/.exec(raw)?.[1]
    return n ? `${base} - ${n}` : base
  }
  return base
}

// Chip color per finish - deliberately avoids blood (red) and pin (green),
// since both already carry win/loss meaning elsewhere in the UI and would
// read as implying a result rather than just naming a finish type.
const RAW_VICTORY_COLOR = {
  fall: 'gold',
  sudden_victory: 'gold',
  tech_fall: 'sky',
  major: 'violet',
}
export function rawVictoryColor(raw) {
  return RAW_VICTORY_COLOR[classifyRawVictoryType(raw)] || 'ink'
}

export function initials(name = '') {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]?.toUpperCase()).join('') || '?'
}

export function plural(n, word, words) {
  return `${n} ${n === 1 ? word : words ?? word + 's'}`
}

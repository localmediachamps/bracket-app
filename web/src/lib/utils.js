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

export function initials(name = '') {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]?.toUpperCase()).join('') || '?'
}

export function plural(n, word, words) {
  return `${n} ${n === 1 ? word : words ?? word + 's'}`
}

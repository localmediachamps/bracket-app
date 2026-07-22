import React, { useEffect, useRef, useState } from 'react'
import { useSearchParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion, AnimatePresence } from 'framer-motion'
import {
  Search, ScrollText, ChevronLeft, ChevronRight, X, Zap, Flame, TrendingUp, Timer,
  Trophy, Rows3, LayoutGrid, SlidersHorizontal,
} from 'lucide-react'
import { api } from '../lib/api'
import { Select, Badge, CardSkeleton, EmptyState, Button, Modal } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { cn, classifyRawVictoryType, rawVictoryLabel, rawVictoryColor } from '../lib/utils'

const WEIGHTS = ['125', '133', '141', '149', '157', '165', '174', '184', '197', '285']
const PER_PAGE = 25

// Icon per finish - the more decisive/dramatic the win, the more it should
// pop. Decision/medical-forfeit/etc fall through to a plain "ink" badge with
// no icon (no bonus, nothing to celebrate).
const VICTORY_ICON = { fall: Zap, tech_fall: Flame, major: TrendingUp, sudden_victory: Timer }
function victoryStyle(victoryType) {
  return { color: rawVictoryColor(victoryType), icon: VICTORY_ICON[classifyRawVictoryType(victoryType)] || null }
}

// "1st/3rd/5th/7th Place Match" round labels are the whole reason a bracket
// exists - they should visually pop out of a scan of the list, not read the
// same as "Quarterfinals" or "Cons. Round 2".
function placementInfo(roundLabel) {
  if (!roundLabel) return null
  const m = /(\d+)(st|nd|rd|th)\s*Place Match/i.exec(roundLabel)
  if (!m) return null
  return { label: `${m[1]}${m[2].toUpperCase()} PLACE`, isChampionship: m[1] === '1' }
}

const listVariants = { hidden: {}, show: { transition: { staggerChildren: 0.03 } } }
const itemVariants = { hidden: { opacity: 0, y: 8 }, show: { opacity: 1, y: 0, transition: { duration: 0.2 } } }

// Same 74 D1 programs for both crawled seasons - static, so no backend
// distinct-query is needed just to populate this dropdown.
const SCHOOLS = [
  'Air Force', 'American', 'Appalachian State', 'Arizona State', 'Army West Point', 'Bellarmine',
  'Binghamton', 'Bloomsburg', 'Brown', 'Bucknell', 'Buffalo', 'CSU Bakersfield', 'Cal Poly',
  'California Baptist', 'Campbell', 'Central Michigan', 'Chattanooga', 'Columbia', 'Cornell',
  'Davidson', 'Drexel', 'Duke', 'Edinboro', 'Franklin & Marshall', 'Gardner-Webb', 'George Mason',
  'Harvard', 'Hofstra', 'Illinois', 'Indiana', 'Iowa', 'Iowa State', 'Kent State', 'Lehigh',
  'Little Rock', 'Lock Haven', 'Maryland', 'Michigan', 'Michigan State', 'Minnesota', 'Missouri',
  'Morgan State', 'NC State', 'Navy', 'Nebraska', 'North Carolina', 'North Dakota State',
  'Northern Colorado', 'Northern Illinois', 'Northern Iowa', 'Northwestern', 'Ohio', 'Ohio State',
  'Oklahoma', 'Oklahoma State', 'Oregon State', 'Penn', 'Penn State', 'Pittsburgh', 'Princeton',
  'Purdue', 'Rider', 'Rutgers', 'SIU Edwardsville', 'South Dakota State', 'Stanford', 'The Citadel',
  'Utah Valley', 'VMI', 'Virginia', 'Virginia Tech', 'West Virginia', 'Wisconsin', 'Wyoming',
]

const SEASONS = [
  { key: 'all', label: 'All time' },
  { key: '2025-26', label: '2025-26 season', start: '2025-11-01', end: '2026-04-01' },
  { key: '2024-25', label: '2024-25 season', start: '2024-11-01', end: '2025-04-01' },
  { key: '2023-24', label: '2023-24 season', start: '2023-11-01', end: '2024-04-01' },
  { key: '2022-23', label: '2022-23 season', start: '2022-11-01', end: '2023-04-01' },
  { key: 'custom', label: 'Custom range' },
]

function formatDate(occurredAt) {
  if (!occurredAt) return '—'
  return new Date(occurredAt).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

// time_seconds is only set for matches that ended early (fall, tech fall,
// injury default) - null means the match went the full scheduled length.
function formatMatchTime(seconds) {
  if (seconds == null) return null
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}:${String(s).padStart(2, '0')}`
}

// Score/time detail line shown under the victory-type badge - "16-7" for a
// decision, "16-7 @ 3:23" for a tech fall, "@ 1:52" for a fall (pins have no
// numeric score, by design). Renders nothing if neither is present.
function MatchDetail({ m, className, fallback }) {
  const time = formatMatchTime(m.time_seconds)
  if (!m.score && !time) return fallback ? <span className={cn('font-mono text-ink-500', className)}>{fallback}</span> : null
  return (
    <span className={cn('font-mono text-[11px] text-ink-500', className)}>
      {m.score}
      {m.score && time && ' '}
      {time && `@ ${time}`}
    </span>
  )
}

// Links to the wrestler's profile when we have a canonical identity for
// this side of the match; plain text otherwise (most historical rows do,
// post-backfill, but not every raw name resolves to one).
function WrestlerName({ name, canonicalId, className }) {
  if (!name) return null
  if (!canonicalId) return <span className={className}>{name}</span>
  return (
    <Link to={`/wrestlers/${canonicalId}`} className={cn(className, 'hover:underline')} onClick={(e) => e.stopPropagation()}>
      {name}
    </Link>
  )
}

function MatchRow({ m }) {
  const { color, icon: Icon } = victoryStyle(m.victory_type)
  const placement = placementInfo(m.round_label)

  return (
    <tr
      className={cn(
        'border-b border-mat-700 last:border-0',
        placement && (placement.isChampionship ? 'bg-gold-500/[0.06] border-l-2 border-l-gold-500' : 'bg-gold-500/[0.03] border-l-2 border-l-gold-500/40')
      )}
    >
      <td className="px-3 py-3">
        <div className="text-sm text-ink-100">
          <WrestlerName name={m.winner_name_raw} canonicalId={m.winner_canonical_wrestler_id} className="font-bold text-pin-400" />
          <span className="text-ink-500"> ({m.winner_school_raw})</span>
        </div>
        <div className="text-sm text-ink-400">
          over <WrestlerName name={m.loser_name_raw || 'opponent'} canonicalId={m.loser_canonical_wrestler_id} className="text-ink-200" />
          {m.loser_school_raw && <span className="text-ink-500"> ({m.loser_school_raw})</span>}
        </div>
      </td>
      <td className="px-3 py-3">
        <Badge color={color}>
          {Icon && <Icon size={11} />} {rawVictoryLabel(m.victory_type) || '—'}
        </Badge>
      </td>
      <td className="px-3 py-3">
        <MatchDetail m={m} className="text-sm font-bold text-ink-100" fallback="—" />
      </td>
      <td className="px-3 py-3">
        {placement ? (
          <Badge color="gold" className={placement.isChampionship ? 'shadow-glow-sm' : ''}>
            <Trophy size={11} /> {placement.label}
          </Badge>
        ) : (
          <span className="text-[11px] uppercase tracking-wider text-ink-500">{m.round_label || '—'}</span>
        )}
      </td>
      <td className="px-3 py-3 text-xs font-bold uppercase tracking-wider text-ink-500">{m.weight_class || '—'}</td>
      <td className="px-3 py-3 text-sm text-ink-400">
        {m.event_name}
        {m.extraction_confidence != null && m.extraction_confidence < 1 && (
          <Badge color="gold" className="ml-2">Unverified</Badge>
        )}
      </td>
      <td className="whitespace-nowrap px-3 py-3 text-xs text-ink-500">{formatDate(m.occurred_at)}</td>
    </tr>
  )
}

function MatchCard({ m }) {
  const { color, icon: Icon } = victoryStyle(m.victory_type)
  const placement = placementInfo(m.round_label)

  return (
    <motion.div
      variants={itemVariants}
      className={cn(
        'group relative overflow-hidden rounded-xl border bg-mat-850 p-4 transition-all hover:-translate-y-0.5 hover:shadow-glow',
        placement ? 'border-gold-500/50 shadow-glow-sm' : 'border-mat-700'
      )}
    >
      <div className="flex items-center justify-between gap-2 pr-2">
        <Badge color="ink">{m.weight_class ? `${m.weight_class} lbs` : '—'}</Badge>
        <span className="shrink-0 text-[11px] text-ink-500">{formatDate(m.occurred_at)}</span>
      </div>
      <div className="mt-3.5">
        <p className="font-bold leading-snug text-ink-50">
          <WrestlerName name={m.winner_name_raw} canonicalId={m.winner_canonical_wrestler_id} />
        </p>
        <p className="text-xs text-ink-500">{m.winner_school_raw}</p>
      </div>
      <p className="my-2 text-[10px] font-bold uppercase tracking-wider text-ink-600">def.</p>
      <div>
        <p className="text-sm text-ink-300">
          <WrestlerName name={m.loser_name_raw || 'opponent'} canonicalId={m.loser_canonical_wrestler_id} />
        </p>
        {m.loser_school_raw && <p className="text-xs text-ink-600">{m.loser_school_raw}</p>}
      </div>

      {/* Result - the headline info this whole card exists to show, so it
          gets the biggest, boldest treatment on the card rather than being
          just another small badge in a row. */}
      <div className="mt-3.5 flex items-center justify-between gap-2 rounded-lg border border-mat-700 bg-mat-900/60 px-3 py-2.5">
        <Badge color={color}>
          {Icon && <Icon size={11} />} {rawVictoryLabel(m.victory_type) || '—'}
        </Badge>
        <MatchDetail m={m} className="text-base font-bold text-ink-100" fallback="—" />
      </div>

      <div className="mt-2.5 flex items-center justify-between gap-2">
        {placement ? (
          <Badge color="gold" className={placement.isChampionship ? 'shadow-glow-sm' : ''}>
            <Trophy size={11} /> {placement.label}
          </Badge>
        ) : (
          <span className="truncate text-[10px] uppercase tracking-wider text-ink-600">{m.round_label || ''}</span>
        )}
        {m.extraction_confidence != null && m.extraction_confidence < 1 && (
          <Badge color="gold">Unverified</Badge>
        )}
      </div>
      <p className="mt-2 truncate text-[11px] text-ink-600">{m.event_name}</p>
    </motion.div>
  )
}

export default function Results() {
  // Deep-linkable from elsewhere in the app (e.g. the Results Analyst chat
  // widget's "View in Results" button) via ?q=&school=&weight_class=&
  // wrestler=&event_name=&start_date=&end_date= - read once on mount as the
  // initial filter state. Not kept in sync afterward (no pushed history on
  // every keystroke) to match this page's existing local-state-only design.
  const [searchParams] = useSearchParams()
  const initialStart = searchParams.get('start_date') || ''
  const initialEnd = searchParams.get('end_date') || ''

  // Master search - hits wrestler name, school, and event name/series at once.
  const [q, setQ] = useState(() => searchParams.get('q') || '')
  const [qd, setQd] = useState(() => searchParams.get('q') || '')
  const [school, setSchool] = useState(() => searchParams.get('school') || '')
  const [weightClass, setWeightClass] = useState(() => searchParams.get('weight_class') || '')
  const [wrestler, setWrestler] = useState(() => searchParams.get('wrestler') || '')
  const [eventName, setEventName] = useState(() => searchParams.get('event_name') || '')
  const [roundLabel, setRoundLabel] = useState(() => searchParams.get('round_label') || '')
  const [season, setSeason] = useState(() => (initialStart || initialEnd ? 'custom' : 'all'))
  const [customStart, setCustomStart] = useState(initialStart)
  const [customEnd, setCustomEnd] = useState(initialEnd)
  const [page, setPage] = useState(1)
  const [filtersOpen, setFiltersOpen] = useState(false)

  // Sticks across visits so a user who prefers the card view doesn't have to
  // re-toggle it every time they come back. Table view forces a min-width
  // (needs the Matchup/Result/Event columns), which is a poor fit for a
  // phone screen - default to cards on mobile unless the user already
  // picked something explicitly.
  const [viewMode, setViewMode] = useState(() => {
    try {
      const stored = localStorage.getItem('mat-savvy-results-view')
      if (stored === 'cards' || stored === 'table') return stored
      return typeof window !== 'undefined' && window.innerWidth < 1024 ? 'cards' : 'table'
    } catch {
      return 'table'
    }
  })
  useEffect(() => {
    try {
      localStorage.setItem('mat-savvy-results-view', viewMode)
    } catch {
      // Ignore storage errors
    }
  }, [viewMode])

  useEffect(() => {
    const t = setTimeout(() => setQd(q.trim()), 300)
    return () => clearTimeout(t)
  }, [q])

  useEffect(() => {
    setPage(1)
  }, [qd, school, weightClass, wrestler, eventName, roundLabel, season, customStart, customEnd])

  // Selecting a school/weight can invalidate a previously-picked wrestler or
  // event that no longer matches - clear them rather than silently filtering
  // on a combination that can never return anything. Compares against the
  // actual last-seen [school, weightClass] (not a one-shot "first mount" flag)
  // so this survives StrictMode's dev-mode double effect invocation without
  // wiping out a deep-linked wrestler/event that arrived alongside them.
  const prevSchoolWeight = useRef([school, weightClass])
  useEffect(() => {
    const [prevSchool, prevWeight] = prevSchoolWeight.current
    if (prevSchool !== school || prevWeight !== weightClass) {
      setWrestler('')
      setEventName('')
      setRoundLabel('')
    }
    prevSchoolWeight.current = [school, weightClass]
  }, [school, weightClass])

  // Changing the event can invalidate a previously-picked round (rounds are
  // event-specific) - clear it rather than filtering on a combination that
  // can never match.
  const prevEvent = useRef(eventName)
  useEffect(() => {
    if (prevEvent.current !== eventName) {
      setRoundLabel('')
    }
    prevEvent.current = eventName
  }, [eventName])

  const activeSeason = SEASONS.find((s) => s.key === season)
  const startDate = season === 'custom' ? customStart : activeSeason?.start
  const endDate = season === 'custom' ? customEnd : activeSeason?.end

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['results', 'search', qd, school, weightClass, wrestler, eventName, roundLabel, startDate, endDate, page],
    queryFn: () =>
      api.searchResults({
        q: qd || undefined,
        school: school || undefined,
        weight_class: weightClass || undefined,
        wrestler: wrestler || undefined,
        event_name: eventName || undefined,
        round_label: roundLabel || undefined,
        start_date: startDate ? new Date(startDate).getTime() : undefined,
        end_date: endDate ? new Date(endDate).getTime() : undefined,
        page,
        per: PER_PAGE,
      }),
    staleTime: 15000,
    keepPreviousData: true,
  })

  // Wrestler + event dropdowns narrow with whichever of school/weight are
  // active; round narrows further by whichever event is selected (rounds are
  // event-specific - "Champ. Round 1" only makes sense within one event).
  const { data: facetData } = useQuery({
    queryKey: ['results', 'facets', school, weightClass, eventName],
    queryFn: () => api.resultsFacets({ school: school || undefined, weight_class: weightClass || undefined, event_name: eventName || undefined }),
    staleTime: 30000,
  })
  const wrestlerOptions = facetData?.wrestlers ?? []
  const eventOptions = facetData?.event_names ?? []
  const roundOptions = facetData?.round_labels ?? []

  const items = data?.items ?? []
  const total = data?.total ?? 0
  const totalPages = Math.max(1, Math.ceil(total / PER_PAGE))

  const filtersActive = q || school || weightClass || wrestler || eventName || roundLabel || season !== 'all'
  const activeFilterCount = [school, weightClass, wrestler, eventName, roundLabel, season !== 'all' ? season : ''].filter(Boolean).length

  const clearFilters = () => {
    setQ('')
    setSchool('')
    setWeightClass('')
    setWrestler('')
    setEventName('')
    setRoundLabel('')
    setSeason('all')
    setCustomStart('')
    setCustomEnd('')
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="font-display text-2xl uppercase tracking-wide text-ink-100">Results</h1>
        <p className="mt-1 text-sm text-ink-500">Explore real historical wrestling match results.</p>
      </div>

      <div className="mb-4 flex flex-col gap-3">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
          <div className="relative flex-1 lg:max-w-sm">
            <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-500" aria-hidden="true" />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Search wrestler, school, or event…"
              aria-label="Search wrestler, school, or event"
              className="h-11 w-full rounded-xl border border-mat-600 bg-mat-800 pl-10 pr-3.5 text-sm text-ink-100 placeholder:text-ink-600 transition-colors hover:border-mat-500 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
            />
          </div>

          {/* Mobile: single button opens the full filter set in a bottom drawer */}
          <div className="flex items-center gap-2 lg:hidden">
            <Button variant="secondary" className="flex-1" onClick={() => setFiltersOpen(true)}>
              <SlidersHorizontal size={15} /> Filters{activeFilterCount > 0 ? ` (${activeFilterCount})` : ''}
            </Button>
            {filtersActive && (
              <Button variant="ghost" size="md" onClick={clearFilters} aria-label="Clear filters">
                <X size={16} />
              </Button>
            )}
          </div>

          {/* Desktop: filters stay inline */}
          <div className="hidden shrink-0 lg:block lg:w-52">
            <Select value={school} onChange={(e) => setSchool(e.target.value)} aria-label="Filter by school">
              <option value="">All schools</option>
              {SCHOOLS.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </Select>
          </div>
          <div className="hidden shrink-0 lg:block lg:w-40">
            <Select value={weightClass} onChange={(e) => setWeightClass(e.target.value)} aria-label="Filter by weight class">
              <option value="">All weights</option>
              {WEIGHTS.map((w) => (
                <option key={w} value={w}>{w} lbs</option>
              ))}
            </Select>
          </div>
        </div>

        <div className="hidden flex-col gap-3 lg:flex lg:flex-row lg:items-center">
          <div className="w-64 shrink-0">
            <Select
              value={wrestler}
              onChange={(e) => setWrestler(e.target.value)}
              aria-label="Filter by specific wrestler"
              disabled={!wrestlerOptions.length}
            >
              <option value="">
                {wrestlerOptions.length ? 'Any wrestler' : 'No wrestlers match yet'}
              </option>
              {wrestlerOptions.map((w) => (
                <option key={w} value={w}>{w}</option>
              ))}
            </Select>
          </div>
          <div className="w-64 shrink-0">
            <Select
              value={eventName}
              onChange={(e) => setEventName(e.target.value)}
              aria-label="Filter by event"
              disabled={!eventOptions.length}
            >
              <option value="">
                {eventOptions.length ? 'Any event' : 'No events match yet'}
              </option>
              {eventOptions.map((e) => (
                <option key={e} value={e}>{e}</option>
              ))}
            </Select>
          </div>
          <div className="w-48 shrink-0">
            <Select
              value={roundLabel}
              onChange={(e) => setRoundLabel(e.target.value)}
              aria-label="Filter by round"
              disabled={!eventName || !roundOptions.length}
            >
              <option value="">
                {!eventName ? 'Pick an event for rounds' : roundOptions.length ? 'Any round' : 'No rounds match yet'}
              </option>
              {roundOptions.map((r) => (
                <option key={r} value={r}>{r}</option>
              ))}
            </Select>
          </div>
          <div className="w-48 shrink-0">
            <Select value={season} onChange={(e) => setSeason(e.target.value)} aria-label="Filter by season">
              {SEASONS.map((s) => (
                <option key={s.key} value={s.key}>{s.label}</option>
              ))}
            </Select>
          </div>
          {season === 'custom' && (
            <div className="flex items-center gap-2">
              <input
                type="date"
                value={customStart}
                onChange={(e) => setCustomStart(e.target.value)}
                aria-label="Start date"
                className="h-11 rounded-xl border border-mat-600 bg-mat-800 px-3 text-sm text-ink-100 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
              />
              <span className="text-ink-500">to</span>
              <input
                type="date"
                value={customEnd}
                onChange={(e) => setCustomEnd(e.target.value)}
                aria-label="End date"
                className="h-11 rounded-xl border border-mat-600 bg-mat-800 px-3 text-sm text-ink-100 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
              />
            </div>
          )}
          {filtersActive && (
            <Button variant="ghost" size="sm" onClick={clearFilters}>
              <X size={14} /> Clear filters
            </Button>
          )}
        </div>
      </div>

      {/* Mobile filter drawer - every selector full width, stacked */}
      <Modal open={filtersOpen} onClose={() => setFiltersOpen(false)} title="Filters">
        <div className="space-y-4">
          <Select value={school} onChange={(e) => setSchool(e.target.value)} aria-label="Filter by school">
            <option value="">All schools</option>
            {SCHOOLS.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </Select>
          <Select value={weightClass} onChange={(e) => setWeightClass(e.target.value)} aria-label="Filter by weight class">
            <option value="">All weights</option>
            {WEIGHTS.map((w) => (
              <option key={w} value={w}>{w} lbs</option>
            ))}
          </Select>
          <Select
            value={wrestler}
            onChange={(e) => setWrestler(e.target.value)}
            aria-label="Filter by specific wrestler"
            disabled={!wrestlerOptions.length}
          >
            <option value="">{wrestlerOptions.length ? 'Any wrestler' : 'No wrestlers match yet'}</option>
            {wrestlerOptions.map((w) => (
              <option key={w} value={w}>{w}</option>
            ))}
          </Select>
          <Select
            value={eventName}
            onChange={(e) => setEventName(e.target.value)}
            aria-label="Filter by event"
            disabled={!eventOptions.length}
          >
            <option value="">{eventOptions.length ? 'Any event' : 'No events match yet'}</option>
            {eventOptions.map((e) => (
              <option key={e} value={e}>{e}</option>
            ))}
          </Select>
          <Select
            value={roundLabel}
            onChange={(e) => setRoundLabel(e.target.value)}
            aria-label="Filter by round"
            disabled={!eventName || !roundOptions.length}
          >
            <option value="">
              {!eventName ? 'Pick an event for rounds' : roundOptions.length ? 'Any round' : 'No rounds match yet'}
            </option>
            {roundOptions.map((r) => (
              <option key={r} value={r}>{r}</option>
            ))}
          </Select>
          <Select value={season} onChange={(e) => setSeason(e.target.value)} aria-label="Filter by season">
            {SEASONS.map((s) => (
              <option key={s.key} value={s.key}>{s.label}</option>
            ))}
          </Select>
          {season === 'custom' && (
            <div className="flex items-center gap-2">
              <input
                type="date"
                value={customStart}
                onChange={(e) => setCustomStart(e.target.value)}
                aria-label="Start date"
                className="h-11 w-full rounded-xl border border-mat-600 bg-mat-800 px-3 text-sm text-ink-100 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
              />
              <span className="shrink-0 text-ink-500">to</span>
              <input
                type="date"
                value={customEnd}
                onChange={(e) => setCustomEnd(e.target.value)}
                aria-label="End date"
                className="h-11 w-full rounded-xl border border-mat-600 bg-mat-800 px-3 text-sm text-ink-100 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
              />
            </div>
          )}
          <div className="flex items-center gap-3 pt-1">
            {filtersActive && (
              <Button variant="ghost" className="flex-1" onClick={clearFilters}>
                <X size={14} /> Clear filters
              </Button>
            )}
            <Button className="flex-1" onClick={() => setFiltersOpen(false)}>
              Show results
            </Button>
          </div>
        </div>
      </Modal>

      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <CardSkeleton key={i} />
          ))}
        </div>
      ) : isError ? (
        <ErrorState error={error} onRetry={refetch} title="Results failed to load" />
      ) : items.length ? (
        <>
          <div className="mb-3 flex items-center justify-between">
            <span className="text-sm text-ink-500">{total} match{total === 1 ? '' : 'es'} found</span>
            <div className="flex items-center gap-1 rounded-lg border border-mat-700 bg-mat-850 p-1" role="tablist" aria-label="Results view">
              <button
                type="button"
                role="tab"
                aria-selected={viewMode === 'table'}
                onClick={() => setViewMode('table')}
                className={cn(
                  'flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-xs font-bold transition-colors',
                  viewMode === 'table' ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200'
                )}
              >
                <Rows3 size={13} /> Table
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={viewMode === 'cards'}
                onClick={() => setViewMode('cards')}
                className={cn(
                  'flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-xs font-bold transition-colors',
                  viewMode === 'cards' ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200'
                )}
              >
                <LayoutGrid size={13} /> Cards
              </button>
            </div>
          </div>

          <AnimatePresence mode="wait">
            {viewMode === 'table' ? (
              <motion.div
                key="table"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.15 }}
                className="overflow-x-auto rounded-xl border border-mat-700 bg-mat-850"
              >
                <table className="w-full min-w-[860px] border-collapse" style={{ tableLayout: 'fixed' }}>
                  <thead>
                    <tr className="border-b border-mat-700 text-left text-[11px] font-bold uppercase tracking-wider text-ink-500">
                      <th className="w-[24%] px-3 py-3">Matchup</th>
                      <th className="w-[12%] px-3 py-3">Victory</th>
                      <th className="w-[11%] px-3 py-3">Score</th>
                      <th className="w-[15%] px-3 py-3">Round</th>
                      <th className="w-14 px-3 py-3">Wt.</th>
                      <th className="w-[19%] px-3 py-3">Event</th>
                      <th className="w-24 whitespace-nowrap px-3 py-3">Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    {items.map((m) => (
                      <MatchRow key={m.id ?? m.source_match_id} m={m} />
                    ))}
                  </tbody>
                </table>
              </motion.div>
            ) : (
              <motion.div
                key="cards"
                variants={listVariants}
                initial="hidden"
                animate="show"
                className="grid grid-cols-1 items-start gap-3 sm:grid-cols-2 xl:grid-cols-3"
              >
                {items.map((m) => (
                  <MatchCard key={m.id ?? m.source_match_id} m={m} />
                ))}
              </motion.div>
            )}
          </AnimatePresence>

          <div className="mt-4 flex items-center justify-end text-sm text-ink-500">
            <div className="flex items-center gap-2">
              <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
                <ChevronLeft size={14} /> Prev
              </Button>
              <span className="px-2 text-xs">Page {page} of {totalPages}</span>
              <Button variant="secondary" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
                Next <ChevronRight size={14} />
              </Button>
            </div>
          </div>
        </>
      ) : (
        <EmptyState
          icon={<ScrollText size={22} />}
          title="No matches found"
          body="Nothing matches those filters — try widening the net."
          action={
            filtersActive ? (
              <Button variant="secondary" size="sm" onClick={clearFilters}>
                Clear filters
              </Button>
            ) : undefined
          }
        />
      )}
    </div>
  )
}

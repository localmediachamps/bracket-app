import React, { useEffect, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Search, ScrollText, ChevronLeft, ChevronRight, X } from 'lucide-react'
import { api } from '../lib/api'
import { Select, Badge, CardSkeleton, EmptyState, Button } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'

const WEIGHTS = ['125', '133', '141', '149', '157', '165', '174', '184', '197', '285']
const PER_PAGE = 25

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
  { key: 'custom', label: 'Custom range' },
]

function formatDate(occurredAt) {
  if (!occurredAt) return '—'
  return new Date(occurredAt).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

function MatchRow({ m }) {
  return (
    <tr className="border-b border-mat-700 last:border-0">
      <td className="whitespace-nowrap px-4 py-3 text-xs text-ink-500">{formatDate(m.occurred_at)}</td>
      <td className="px-4 py-3 text-xs font-bold uppercase tracking-wider text-ink-500">{m.weight_class || '—'}</td>
      <td className="px-4 py-3">
        <div className="text-sm text-ink-100">
          <span className="font-bold text-pin-400">{m.winner_name_raw}</span>
          <span className="text-ink-500"> ({m.winner_school_raw})</span>
        </div>
        <div className="text-sm text-ink-400">
          over <span className="text-ink-200">{m.loser_name_raw || 'opponent'}</span>
          {m.loser_school_raw && <span className="text-ink-500"> ({m.loser_school_raw})</span>}
        </div>
      </td>
      <td className="px-4 py-3">
        <Badge color="ink">{m.victory_type || '—'}</Badge>
        {m.round_label && <div className="mt-1 text-[11px] uppercase tracking-wider text-ink-500">{m.round_label}</div>}
      </td>
      <td className="px-4 py-3 text-sm text-ink-400">
        {m.event_name}
        {m.extraction_confidence != null && m.extraction_confidence < 1 && (
          <Badge color="gold" className="ml-2">Unverified</Badge>
        )}
      </td>
    </tr>
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
  const [season, setSeason] = useState(() => (initialStart || initialEnd ? 'custom' : 'all'))
  const [customStart, setCustomStart] = useState(initialStart)
  const [customEnd, setCustomEnd] = useState(initialEnd)
  const [page, setPage] = useState(1)

  useEffect(() => {
    const t = setTimeout(() => setQd(q.trim()), 300)
    return () => clearTimeout(t)
  }, [q])

  useEffect(() => {
    setPage(1)
  }, [qd, school, weightClass, wrestler, eventName, season, customStart, customEnd])

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
    }
    prevSchoolWeight.current = [school, weightClass]
  }, [school, weightClass])

  const activeSeason = SEASONS.find((s) => s.key === season)
  const startDate = season === 'custom' ? customStart : activeSeason?.start
  const endDate = season === 'custom' ? customEnd : activeSeason?.end

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['results', 'search', qd, school, weightClass, wrestler, eventName, startDate, endDate, page],
    queryFn: () =>
      api.searchResults({
        q: qd || undefined,
        school: school || undefined,
        weight_class: weightClass || undefined,
        wrestler: wrestler || undefined,
        event_name: eventName || undefined,
        start_date: startDate ? new Date(startDate).getTime() : undefined,
        end_date: endDate ? new Date(endDate).getTime() : undefined,
        page,
        per: PER_PAGE,
      }),
    staleTime: 15000,
    keepPreviousData: true,
  })

  // Wrestler + event dropdowns narrow with whichever of school/weight are
  // active, so picking a school/weight first shows only values that
  // actually occur in that slice of the data.
  const { data: facetData } = useQuery({
    queryKey: ['results', 'facets', school, weightClass],
    queryFn: () => api.resultsFacets({ school: school || undefined, weight_class: weightClass || undefined }),
    staleTime: 30000,
  })
  const wrestlerOptions = facetData?.wrestlers ?? []
  const eventOptions = facetData?.event_names ?? []

  const items = data?.items ?? []
  const total = data?.total ?? 0
  const totalPages = Math.max(1, Math.ceil(total / PER_PAGE))

  const filtersActive = q || school || weightClass || wrestler || eventName || season !== 'all'

  const clearFilters = () => {
    setQ('')
    setSchool('')
    setWeightClass('')
    setWrestler('')
    setEventName('')
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
          <div className="w-52 shrink-0">
            <Select value={school} onChange={(e) => setSchool(e.target.value)} aria-label="Filter by school">
              <option value="">All schools</option>
              {SCHOOLS.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </Select>
          </div>
          <div className="w-40 shrink-0">
            <Select value={weightClass} onChange={(e) => setWeightClass(e.target.value)} aria-label="Filter by weight class">
              <option value="">All weights</option>
              {WEIGHTS.map((w) => (
                <option key={w} value={w}>{w} lbs</option>
              ))}
            </Select>
          </div>
        </div>

        <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
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
          <div className="overflow-x-auto rounded-xl border border-mat-700 bg-mat-850">
            <table className="w-full min-w-[720px] border-collapse">
              <thead>
                <tr className="border-b border-mat-700 text-left text-[11px] font-bold uppercase tracking-wider text-ink-500">
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3">Weight</th>
                  <th className="px-4 py-3">Matchup</th>
                  <th className="px-4 py-3">Result</th>
                  <th className="px-4 py-3">Event</th>
                </tr>
              </thead>
              <tbody>
                {items.map((m) => (
                  <MatchRow key={m.id ?? m.source_match_id} m={m} />
                ))}
              </tbody>
            </table>
          </div>

          <div className="mt-4 flex items-center justify-between text-sm text-ink-500">
            <span>{total} match{total === 1 ? '' : 'es'} found</span>
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

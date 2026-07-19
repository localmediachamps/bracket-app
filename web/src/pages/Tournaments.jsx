import React, { useEffect, useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Search, Trophy } from 'lucide-react'
import { api } from '../lib/api'
import { CardSkeleton, EmptyState, Select, Button } from '../components/ui'
import TournamentCard from '../components/tournament/TournamentCard'
import { ErrorState } from '../components/tournament/Feedback'
import { normalizeList } from '../components/tournament/helpers'
import { cn } from '../lib/utils'

const FILTERS = [
  { key: '', label: 'All' },
  { key: 'open', label: 'Open' },
  { key: 'live', label: 'Live' },
  { key: 'locked', label: 'Locked' },
  { key: 'completed', label: 'Completed' },
]

const SORTS = [
  { key: 'locks', label: 'Soonest locking' },
  { key: 'newest', label: 'Newest' },
  { key: 'players', label: 'Most players' },
]

function sortItems(items, sort) {
  const arr = [...items]
  if (sort === 'players') return arr.sort((a, b) => (b.entry_count ?? 0) - (a.entry_count ?? 0))
  if (sort === 'newest')
    return arr.sort((a, b) => +new Date(b.created_at ?? 0) - +new Date(a.created_at ?? 0) || (b.year ?? 0) - (a.year ?? 0))
  return arr.sort((a, b) => (a.locks_at ? +new Date(a.locks_at) : Infinity) - (b.locks_at ? +new Date(b.locks_at) : Infinity))
}

export default function Tournaments() {
  const [status, setStatus] = useState('')
  const [q, setQ] = useState('')
  const [qd, setQd] = useState('')
  const [sort, setSort] = useState('locks')

  // debounced search (300ms)
  useEffect(() => {
    const t = setTimeout(() => setQd(q.trim()), 300)
    return () => clearTimeout(t)
  }, [q])

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['tournaments', 'directory', status, qd],
    queryFn: () => api.tournaments({ status: status || undefined, q: qd || undefined, per: 60 }),
    staleTime: 30000,
  })

  const { items, total } = normalizeList(data)
  const sorted = useMemo(() => sortItems(items, sort), [items, sort])
  const filtering = !!status || !!qd

  return (
    <div>
      {/* header */}
      <div className="mb-6">
        <h1 className="font-display text-2xl uppercase tracking-wide text-ink-100">Tournaments</h1>
        <p className="mt-1 text-sm text-ink-500">
          {isLoading ? 'Loading the arena…' : `${total} tournament${total === 1 ? '' : 's'} on the board`}
        </p>
      </div>

      {/* controls */}
      <div className="mb-6 flex flex-col gap-3 lg:flex-row lg:items-center">
        <div className="flex flex-wrap gap-2" role="group" aria-label="Filter by status">
          {FILTERS.map((f) => (
            <button
              key={f.key}
              onClick={() => setStatus(f.key)}
              aria-pressed={status === f.key}
              className={cn(
                'rounded-full border px-4 py-2 text-xs font-bold uppercase tracking-wider transition-all',
                status === f.key
                  ? 'border-gold-500/60 bg-gold-500/12 text-gold-300 shadow-glow-sm'
                  : 'border-mat-600 bg-mat-850 text-ink-400 hover:border-mat-500 hover:text-ink-100'
              )}
            >
              {f.label}
            </button>
          ))}
        </div>
        <div className="flex flex-1 items-center gap-3 lg:justify-end">
          <div className="relative w-full lg:w-72">
            <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-500" aria-hidden="true" />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Search tournaments…"
              aria-label="Search tournaments"
              className="h-11 w-full rounded-xl border border-mat-600 bg-mat-800 pl-10 pr-3.5 text-sm text-ink-100 placeholder:text-ink-600 transition-colors hover:border-mat-500 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
            />
          </div>
          <div className="w-44 shrink-0">
            <Select value={sort} onChange={(e) => setSort(e.target.value)} aria-label="Sort tournaments">
              {SORTS.map((s) => (
                <option key={s.key} value={s.key}>
                  {s.label}
                </option>
              ))}
            </Select>
          </div>
        </div>
      </div>

      {/* grid */}
      {isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <CardSkeleton key={i} />
          ))}
        </div>
      ) : isError ? (
        <ErrorState error={error} onRetry={refetch} title="Tournaments failed to load" />
      ) : sorted.length ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {sorted.map((t, i) => (
            <TournamentCard key={t.id} tournament={t} index={i} />
          ))}
        </div>
      ) : (
        <EmptyState
          icon={<Trophy size={22} />}
          title="No tournaments found"
          body={
            filtering
              ? 'Nothing matches those filters — try widening the net.'
              : 'The first tournament is being seeded right now. Check back soon.'
          }
          action={
            filtering ? (
              <Button
                variant="secondary"
                size="sm"
                onClick={() => {
                  setStatus('')
                  setQ('')
                  setQd('')
                }}
              >
                Clear filters
              </Button>
            ) : undefined
          }
        />
      )}
    </div>
  )
}

import React, { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Activity, ChevronLeft, ChevronRight } from 'lucide-react'
import { api } from '../../lib/api'
import { Badge, Button, Card, EmptyState, Select, Skeleton } from '../ui'
import { formatDateTime, victoryLabel } from '../../lib/utils'
import { normalizeList, resultSides } from './helpers'
import { ErrorState } from './Feedback'

const PER = 25

function ResultRow({ match: m }) {
  const { winner, loser } = resultSides(m)
  return (
    <div className="flex flex-wrap items-center gap-x-4 gap-y-1.5 border-t border-mat-700/60 px-4 py-3 first:border-t-0">
      <div className="w-28 shrink-0">
        <p className="truncate text-[10px] font-bold uppercase tracking-wider text-ink-500">{m.round_label ?? 'Match'}</p>
        <p className="font-mono text-[10px] text-ink-600">#{m.match_number ?? m.id}</p>
      </div>
      <div className="min-w-0 flex-1 text-sm">
        {winner ? (
          <span className="font-bold text-pin-300">
            {winner.seed != null && <sup className="mr-1 font-mono text-[10px] font-bold text-gold-500">{winner.seed}</sup>}
            {winner.name}
            {winner.school && <span className="ml-1.5 text-xs font-normal text-ink-500">{winner.school}</span>}
          </span>
        ) : (
          <span className="text-ink-500">TBD</span>
        )}
        <span className="mx-2 text-[10px] font-bold uppercase tracking-wider text-ink-600">def.</span>
        {loser ? (
          <span className="text-ink-400">
            {loser.seed != null && <sup className="mr-1 font-mono text-[10px] text-ink-600">{loser.seed}</sup>}
            {loser.name}
            {loser.school && <span className="ml-1.5 text-xs text-ink-600">{loser.school}</span>}
          </span>
        ) : (
          <span className="text-ink-600">TBD</span>
        )}
      </div>
      <div className="flex shrink-0 items-center gap-2">
        {m.victory_type && <Badge color="pin">{victoryLabel(m.victory_type)}</Badge>}
        {m.score && <span className="font-mono text-xs font-bold text-ink-300">{m.score}</span>}
        {m.completed_at && <span className="hidden text-[10px] text-ink-600 sm:inline">{formatDateTime(m.completed_at)}</span>}
      </div>
    </div>
  )
}

/**
 * ResultsPanel — completed-match feed grouped by weight, with weight filter.
 */
export default function ResultsPanel({ tournament, weights }) {
  const [wc, setWc] = useState('')
  const [page, setPage] = useState(1)

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['results', tournament.id, wc, page],
    queryFn: () => api.results(tournament.id, { weight_class_id: wc || undefined, page, per: PER }),
    staleTime: 30000,
  })

  const { items, totalPages } = normalizeList(data)

  const groups = useMemo(() => {
    const map = new Map()
    for (const m of items) {
      const key = m.weight_class_id ?? 'other'
      if (!map.has(key)) map.set(key, [])
      map.get(key).push(m)
    }
    return [...map.entries()]
  }, [items])

  const labelFor = (key, sample) => {
    const w = weights.find((x) => String(x.id) === String(key))
    if (w) return w.name ?? `${w.weight} lbs`
    if (sample?.weight_class_name) return sample.weight_class_name
    if (sample?.weight != null) return `${sample.weight} lbs`
    return 'Matches'
  }

  return (
    <div>
      <div className="mb-5 flex items-center justify-between gap-3">
        <div className="w-56 max-w-full">
          <Select
            value={wc}
            onChange={(e) => {
              setWc(e.target.value)
              setPage(1)
            }}
            aria-label="Filter results by weight"
          >
            <option value="">All weights</option>
            {weights.map((w) => (
              <option key={w.id} value={w.id}>
                {w.name ?? `${w.weight} lbs`}
              </option>
            ))}
          </Select>
        </div>
      </div>

      {isLoading ? (
        <div className="space-y-3" aria-busy="true" aria-label="Loading results">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-14 w-full" />
          ))}
        </div>
      ) : isError ? (
        <ErrorState error={error} onRetry={refetch} title="Results failed to load" />
      ) : !items.length ? (
        <EmptyState
          icon={<Activity size={22} />}
          title="No results yet"
          body="Completed matches will stream in here once the tournament goes live."
        />
      ) : (
        <>
          <div className="space-y-5">
            {groups.map(([key, matches]) => (
              <section key={key}>
                <h3 className="mb-2 text-[11px] font-bold uppercase tracking-[0.14em] text-gold-400">
                  {labelFor(key, matches[0])}
                  <span className="ml-2 font-mono text-[9px] font-normal text-ink-600">{matches.length}</span>
                </h3>
                <Card className="overflow-hidden">
                  {matches.map((m) => (
                    <ResultRow key={m.id} match={m} />
                  ))}
                </Card>
              </section>
            ))}
          </div>

          {(totalPages > 1 || page > 1) && (
            <div className="mt-4 flex items-center justify-between">
              <span className="text-xs text-ink-500">
                Page {page} of {totalPages}
              </span>
              <div className="flex gap-2">
                <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)} aria-label="Previous page">
                  <ChevronLeft size={14} /> Prev
                </Button>
                <Button
                  variant="secondary"
                  size="sm"
                  disabled={page >= totalPages}
                  onClick={() => setPage((p) => p + 1)}
                  aria-label="Next page"
                >
                  Next <ChevronRight size={14} />
                </Button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  )
}

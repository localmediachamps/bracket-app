import React, { useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { GitBranch } from 'lucide-react'
import { api } from '../../lib/api'
import { EmptyState, Skeleton } from '../ui'
import BracketView from '../bracket/BracketView'
import WeightRail from './WeightRail'
import { ErrorState } from './Feedback'

function BracketSkeleton() {
  return (
    <div aria-busy="true" aria-label="Loading bracket">
      <div className="mb-3 flex items-center justify-between">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-4 w-28" />
      </div>
      <Skeleton className="h-[440px] w-full rounded-xl" />
    </div>
  )
}

/**
 * BracketPanel — weight rail + readonly/results BracketView for the hub.
 * When the viewer owns an entry (myEntry) we pass entry_id so user picks
 * come back on each match and render in 'results' mode.
 */
export default function BracketPanel({ tournament, weights, myEntry }) {
  const [activeId, setActiveId] = useState(null)
  const [stats, setStats] = useState({})
  const activeWc = activeId ?? weights[0]?.id

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['bracket', tournament.id, activeWc, myEntry?.id ?? 'anon'],
    queryFn: () => api.bracketView(tournament.id, activeWc, myEntry?.id || undefined),
    enabled: !!activeWc,
    staleTime: 30000,
  })

  // Per-weight completion, derived from match_status counts once loaded.
  useEffect(() => {
    if (!data?.matches?.length || !activeWc) return
    const done = data.matches.filter((m) => m.status === 'complete' || m.status === 'corrected').length
    const total = data.matches.length
    setStats((s) => (s[activeWc]?.done === done && s[activeWc]?.total === total ? s : { ...s, [activeWc]: { done, total } }))
  }, [data, activeWc])

  if (!weights.length) {
    return (
      <EmptyState
        icon={<GitBranch size={22} />}
        title="No weight classes yet"
        body="Brackets will appear here once the tournament's weight classes are published."
      />
    )
  }

  return (
    <div>
      <WeightRail weights={weights} activeId={activeWc} onChange={setActiveId} stats={stats} />
      <div className="mt-4">
        {isLoading ? (
          <BracketSkeleton />
        ) : isError ? (
          <ErrorState error={error} onRetry={refetch} title="Bracket failed to load" />
        ) : (
          <BracketView data={data} mode={myEntry ? 'results' : 'readonly'} />
        )}
      </div>
    </div>
  )
}

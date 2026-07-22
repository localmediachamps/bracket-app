import React, { useState } from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Swords, Calendar } from 'lucide-react'
import { api } from '../lib/api'
import { CardSkeleton, EmptyState, Card, StatusPill } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { normalizeList } from '../components/tournament/helpers'
import { formatDate, cn } from '../lib/utils'

const FILTERS = [
  { key: '', label: 'All' },
  { key: 'open', label: 'Open' },
  { key: 'locked', label: 'Locked' },
  { key: 'completed', label: 'Completed' },
]

function DualMeetCard({ dm, index }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 18 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.4, delay: Math.min(index * 0.06, 0.36), ease: [0.22, 1, 0.36, 1] }}
    >
      <Link to={`/dual-meets/${dm.slug ?? dm.id}`} className="group block h-full">
        <Card hover className="flex h-full flex-col p-5">
          <div className="flex items-start justify-between gap-3">
            <h3 className="min-w-0 break-words font-display text-base uppercase leading-tight tracking-wide text-ink-100 transition-colors group-hover:text-gold-300">
              {dm.away_team_name} at {dm.home_team_name}
            </h3>
            <StatusPill status={dm.status} className="shrink-0" />
          </div>
          <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-ink-500">
            {dm.year && <span className="font-mono">{dm.year}</span>}
            {dm.occurred_at && (
              <span className="inline-flex items-center gap-1">
                <Calendar size={12} /> {formatDate(dm.occurred_at)}
              </span>
            )}
          </div>
          <div className="mt-auto flex items-center justify-between pt-4 text-xs text-ink-500">
            <span>{dm.entry_count ?? 0} picks in</span>
            <span className="inline-flex items-center gap-1 font-bold text-gold-500 opacity-0 transition-all duration-200 group-hover:translate-x-0.5 group-hover:opacity-100">
              View →
            </span>
          </div>
        </Card>
      </Link>
    </motion.div>
  )
}

export default function DualMeets() {
  const [status, setStatus] = useState('')

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['dual-meets', status],
    queryFn: () => api.dualMeets({ status: status || undefined, per: 60 }),
    staleTime: 30000,
  })

  const { items, total } = normalizeList(data)

  return (
    <div>
      <div className="mb-6">
        <h1 className="font-display text-2xl uppercase tracking-wide text-ink-100">Dual Meets</h1>
        <p className="mt-1 text-sm text-ink-500">
          {isLoading ? 'Loading dual meets…' : `${total} dual meet${total === 1 ? '' : 's'} on the board`}
        </p>
      </div>

      <div className="mb-6 flex flex-wrap gap-2" role="group" aria-label="Filter by status">
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

      {isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <CardSkeleton key={i} />
          ))}
        </div>
      ) : isError ? (
        <ErrorState error={error} onRetry={refetch} title="Couldn't load dual meets" />
      ) : items.length ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((dm, i) => (
            <DualMeetCard key={dm.id} dm={dm} index={i} />
          ))}
        </div>
      ) : (
        <EmptyState
          icon={<Swords size={22} />}
          title="No dual meets yet"
          body="Check back soon — dual meet picks are on their way."
        />
      )}
    </div>
  )
}

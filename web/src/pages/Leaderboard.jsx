import React, { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Trophy, Crown, Medal, ChevronLeft, ChevronRight, Search, SearchX } from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore } from '../lib/store'
import { Avatar, Button, Card, CardSkeleton, EmptyState, SectionHeading, Skeleton, StatusPill, Tabs } from '../components/ui'
import LeaderboardPanel from '../components/tournament/LeaderboardPanel'
import { ErrorState } from '../components/tournament/Feedback'
import { normalizeList, displayName } from '../components/tournament/helpers'
import { cn, formatPoints } from '../lib/utils'

const PER = 25

const PODIUM = {
  1: { card: 'border-gold-500/60 shadow-glow sm:-translate-y-3', icon: Crown, iconCls: 'text-gold-400', ring: true },
  2: { card: 'border-ink-300/25', icon: Medal, iconCls: 'text-ink-300', ring: false },
  3: { card: 'border-blood-500/35', icon: Medal, iconCls: 'text-blood-400', ring: false },
}

function MasterPodiumCard({ row, place, index }) {
  const u = row.user ?? row
  const cfg = PODIUM[place]
  const Icon = cfg.icon
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.08 * index, duration: 0.35, ease: [0.22, 1, 0.36, 1] }}
      className={cn(place === 1 && 'sm:order-2', place === 2 && 'sm:order-1', place === 3 && 'sm:order-3')}
    >
      <Card className={cn('flex flex-col items-center px-4 py-6 text-center', cfg.card)}>
        <span className={cn('mb-2 flex h-9 w-9 items-center justify-center rounded-full bg-mat-800', cfg.iconCls)}>
          <Icon size={18} />
        </span>
        <Avatar user={u} size="lg" ring={cfg.ring} />
        <Link to={`/users/${u.id}`} className="mt-3 block max-w-full truncate text-sm font-bold text-ink-100 hover:text-gold-300">
          {displayName(u)}
        </Link>
        {u.username && <span className="block max-w-full truncate text-xs text-ink-500">@{u.username}</span>}
        <span className="mt-2 font-mono text-xl font-bold text-gold-400">{formatPoints(row.total_points)}</span>
        <span className="text-[10px] font-bold uppercase tracking-[0.14em] text-ink-600">points</span>
      </Card>
    </motion.div>
  )
}

function MasterTab() {
  const me = useAuthStore((s) => s.user)
  const [page, setPage] = useState(1)

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['platform-leaderboard', page],
    queryFn: () => api.platformLeaderboard({ page, per: PER }),
    staleTime: 30000,
  })

  const { items, total, totalPages } = normalizeList(data)
  const podium = page === 1 ? items.slice(0, 3) : []
  const rows = items

  if (isLoading) {
    return (
      <div className="space-y-2" aria-busy="true" aria-label="Loading master leaderboard">
        <div className="grid gap-4 sm:grid-cols-3">
          <Skeleton className="h-44" />
          <Skeleton className="h-44" />
          <Skeleton className="h-44" />
        </div>
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton key={i} className="h-12 w-full" />
        ))}
      </div>
    )
  }

  if (isError) return <ErrorState error={error} onRetry={refetch} title="Master leaderboard failed to load" />

  if (!items.length) {
    return (
      <EmptyState
        icon={<Trophy size={22} />}
        title="No ranked entries yet"
        body="Once players finish tournaments, their points show up here — summed across every event they've entered this season."
      />
    )
  }

  return (
    <>
      {podium.length > 0 && (
        <div className="mb-6 grid gap-4 sm:grid-cols-3">
          {podium.map((row, i) => (
            <MasterPodiumCard key={row.user?.id ?? i} row={row} place={i + 1} index={i} />
          ))}
        </div>
      )}

      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[420px] text-sm">
            <thead>
              <tr className="text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
                <th className="px-4 py-3">Rank</th>
                <th className="px-4 py-3">Player</th>
                <th className="px-4 py-3 text-right">Points</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, i) => {
                const u = row.user ?? row
                const isMe = me?.id != null && u.id === me.id
                return (
                  <tr
                    key={u.id ?? i}
                    className={cn(
                      'border-t border-mat-700/70 transition-colors hover:bg-mat-800/50',
                      isMe && 'border-l-2 border-l-gold-500 bg-gold-500/[0.06]'
                    )}
                  >
                    <td className="px-4 py-3 font-mono font-bold text-ink-100">{row.rank ?? '—'}</td>
                    <td className="px-4 py-3">
                      <Link to={`/users/${u.id}`} className="group flex items-center gap-2.5">
                        <Avatar user={u} size="xs" />
                        <span className="min-w-0">
                          <span className="block truncate font-semibold text-ink-100 group-hover:text-gold-300">
                            {displayName(u)}
                            {isMe && <span className="ml-1.5 text-[10px] font-bold uppercase text-gold-500">you</span>}
                          </span>
                          {u.username && <span className="block truncate text-xs text-ink-500">@{u.username}</span>}
                        </span>
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-right font-mono font-bold text-gold-400">{formatPoints(row.total_points)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </Card>

      {(totalPages > 1 || page > 1) && (
        <div className="mt-4 flex items-center justify-between">
          <span className="text-xs text-ink-500">
            Page {page} of {totalPages} · {total} players
          </span>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)} aria-label="Previous page">
              <ChevronLeft size={14} /> Prev
            </Button>
            <Button variant="secondary" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)} aria-label="Next page">
              Next <ChevronRight size={14} />
            </Button>
          </div>
        </div>
      )}
    </>
  )
}

function EventTab() {
  const [searchParams, setSearchParams] = useSearchParams()
  const selectedSlug = searchParams.get('event') || ''
  const [q, setQ] = useState('')
  const [qd, setQd] = useState('')

  useEffect(() => {
    const t = setTimeout(() => setQd(q.trim()), 300)
    return () => clearTimeout(t)
  }, [q])

  const listQ = useQuery({
    queryKey: ['tournaments', 'leaderboard-picker', qd],
    queryFn: () => api.tournaments({ q: qd || undefined, per: 60 }),
    staleTime: 30000,
  })
  const { items: tournaments } = normalizeList(listQ.data)

  const selectedQ = useQuery({
    queryKey: ['tournament', selectedSlug],
    queryFn: () => api.tournament(selectedSlug),
    enabled: !!selectedSlug,
    staleTime: 30000,
  })

  const selectEvent = (slug) => {
    const p = new URLSearchParams(searchParams)
    p.set('event', slug)
    setSearchParams(p, { replace: true })
  }

  return (
    <div>
      <div className="relative mb-4">
        <Search size={16} className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-500" />
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search tournaments…"
          className="w-full rounded-xl border border-mat-600 bg-mat-800 py-2.5 pl-10 pr-4 text-sm text-ink-100 placeholder:text-ink-600 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
        />
      </div>

      {listQ.isLoading ? (
        <CardSkeleton />
      ) : listQ.isError ? (
        <ErrorState error={listQ.error} onRetry={listQ.refetch} title="Couldn't load tournaments" />
      ) : tournaments.length ? (
        <Card className="mb-6 max-h-72 overflow-y-auto">
          {tournaments.map((t, i) => (
            <button
              key={t.id}
              onClick={() => selectEvent(t.slug ?? t.id)}
              className={cn(
                'flex w-full items-center gap-3 border-t border-mat-700/60 px-4 py-3 text-left transition-colors first:border-t-0 hover:bg-mat-800/50',
                (t.slug ?? String(t.id)) === selectedSlug && 'bg-gold-500/[0.08]'
              )}
            >
              <span className="min-w-0 flex-1 truncate text-sm font-semibold text-ink-100">{t.name}</span>
              {t.year && <span className="shrink-0 font-mono text-xs text-ink-500">{t.year}</span>}
              <StatusPill status={t.status} className="shrink-0" />
            </button>
          ))}
        </Card>
      ) : (
        <EmptyState icon={<SearchX size={20} />} title="No tournaments found" body="Try a different search." />
      )}

      {selectedSlug && (
        <motion.div key={selectedSlug} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.25 }}>
          {selectedQ.isLoading ? (
            <CardSkeleton />
          ) : selectedQ.isError ? (
            <ErrorState error={selectedQ.error} onRetry={selectedQ.refetch} title="Tournament failed to load" />
          ) : selectedQ.data ? (
            <>
              <SectionHeading sub="Ranked entries for this event only.">{selectedQ.data.name}</SectionHeading>
              <LeaderboardPanel tournament={selectedQ.data} />
            </>
          ) : null}
        </motion.div>
      )}
    </div>
  )
}

export default function Leaderboard() {
  const [searchParams, setSearchParams] = useSearchParams()
  const view = searchParams.get('view') === 'event' ? 'event' : 'master'

  const setView = (key) => {
    const p = new URLSearchParams(searchParams)
    p.set('view', key)
    if (key === 'master') p.delete('event')
    setSearchParams(p, { replace: true })
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="font-display text-2xl uppercase tracking-wide text-ink-100">Leaderboard</h1>
        <p className="mt-1 text-sm text-ink-500">
          Points from every bracket and pick'em entry, summed across the season. Keep entering to keep climbing.
        </p>
      </div>

      <Tabs
        className="mb-6"
        tabs={[
          { key: 'master', label: 'Master', icon: <Trophy size={15} /> },
          { key: 'event', label: 'By Event', icon: <Crown size={15} /> },
        ]}
        active={view}
        onChange={setView}
      />

      {view === 'master' ? <MasterTab /> : <EventTab />}
    </div>
  )
}

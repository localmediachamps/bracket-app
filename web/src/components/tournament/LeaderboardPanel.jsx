import React, { useState } from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Trophy, Crown, Medal, ChevronLeft, ChevronRight, GitBranch, Scale } from 'lucide-react'
import { api } from '../../lib/api'
import { useAuthStore } from '../../lib/store'
import { Avatar, Badge, Button, Card, EmptyState, RankChange, Skeleton } from '../ui'
import { cn, formatPoints, pct } from '../../lib/utils'
import { normalizeList, displayName, asModes } from './helpers'
import { ErrorState } from './Feedback'

const PER = 25

const PODIUM = {
  1: { card: 'border-gold-500/60 shadow-glow sm:-translate-y-3', icon: Crown, iconCls: 'text-gold-400', ring: true },
  2: { card: 'border-ink-300/25', icon: Medal, iconCls: 'text-ink-300', ring: false },
  3: { card: 'border-blood-500/35', icon: Medal, iconCls: 'text-blood-400', ring: false },
}

function PodiumCard({ row, place, index }) {
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

function TableSkeleton() {
  return (
    <div className="space-y-2" aria-busy="true" aria-label="Loading leaderboard">
      <div className="grid grid-cols-3 gap-4">
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

/** Accuracy bar — thin pin bar with % label (color + text, never color alone). */
function AccuracyBar({ correct, scored }) {
  if (!scored) return <span className="text-xs text-ink-600">—</span>
  const ratio = correct / scored
  return (
    <span className="inline-flex items-center gap-2">
      <span className="h-1.5 w-16 overflow-hidden rounded-full bg-mat-700">
        <span className="block h-full rounded-full bg-pin-500" style={{ width: `${Math.min(100, ratio * 100)}%` }} />
      </span>
      <span className="font-mono text-xs text-ink-400">{pct(ratio)}</span>
    </span>
  )
}

/**
 * LeaderboardPanel — podium top-3, ranked table, pagination, bracket/pick'em toggle.
 */
export default function LeaderboardPanel({ tournament }) {
  const me = useAuthStore((s) => s.user)
  const modes = asModes(tournament.game_modes)
  const hasBracket = modes.includes('bracket')
  const hasPickem = modes.includes('pickem')
  const [mode, setMode] = useState(hasBracket ? 'bracket' : 'pickem')
  const [page, setPage] = useState(1)

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['leaderboard', tournament.id, mode, page],
    queryFn: () => api.leaderboard(tournament.id, { mode, page, per: PER }),
    staleTime: 30000,
  })

  const { items, total, totalPages } = normalizeList(data)
  const podium = page === 1 ? items.slice(0, 3) : []
  const rows = page === 1 ? items.slice(3) : items

  const switchMode = (m) => {
    setMode(m)
    setPage(1)
  }

  return (
    <div>
      {hasBracket && hasPickem && (
        <div className="mb-5 inline-flex items-center gap-1 rounded-lg border border-mat-700 bg-mat-850 p-1" role="tablist" aria-label="Leaderboard mode">
          {[
            { key: 'bracket', label: 'Bracket', icon: GitBranch },
            { key: 'pickem', label: "Pick'em", icon: Scale },
          ].map((m) => (
            <button
              key={m.key}
              role="tab"
              aria-selected={mode === m.key}
              onClick={() => switchMode(m.key)}
              className={cn(
                'flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-bold transition-colors',
                mode === m.key ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200'
              )}
            >
              <m.icon size={13} /> {m.label}
            </button>
          ))}
        </div>
      )}

      {isLoading ? (
        <TableSkeleton />
      ) : isError ? (
        <ErrorState error={error} onRetry={refetch} title="Leaderboard failed to load" />
      ) : !items.length ? (
        <EmptyState
          icon={<Trophy size={22} />}
          title="No ranked entries yet"
          body="Entries appear here once players submit their picks. The podium is wide open."
        />
      ) : (
        <>
          {podium.length > 0 && (
            <div className="mb-6 grid gap-4 sm:grid-cols-3">
              {podium.map((row, i) => (
                <PodiumCard key={row.id ?? row.user?.id ?? i} row={row} place={i + 1} index={i} />
              ))}
            </div>
          )}

          {rows.length > 0 && (
            <Card className="overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full min-w-[640px] text-sm">
                  <thead>
                    <tr className="text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
                      <th className="px-4 py-3">Rank</th>
                      <th className="px-4 py-3">Player</th>
                      <th className="px-4 py-3 text-right">Points</th>
                      {mode === 'bracket' && <th className="hidden px-4 py-3 text-right md:table-cell">Possible</th>}
                      {mode === 'bracket' && <th className="hidden px-4 py-3 text-right md:table-cell">Correct</th>}
                      {mode === 'bracket' && <th className="hidden px-4 py-3 lg:table-cell">Accuracy</th>}
                      {mode === 'bracket' && <th className="hidden px-4 py-3 text-right lg:table-cell">Champs</th>}
                      <th className="px-4 py-3 text-right">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((row, i) => {
                      const u = row.user ?? row
                      const isMe = me?.id != null && u.id === me.id
                      return (
                        <tr
                          key={row.id ?? u.id ?? i}
                          className={cn(
                            'border-t border-mat-700/70 transition-colors hover:bg-mat-800/50',
                            isMe && 'border-l-2 border-l-gold-500 bg-gold-500/[0.06]'
                          )}
                        >
                          <td className="px-4 py-3">
                            <span className="inline-flex items-center gap-2">
                              <span className="font-mono font-bold text-ink-100">{row.rank ?? '—'}</span>
                              <RankChange value={row.rank_change} />
                            </span>
                          </td>
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
                          {mode === 'bracket' && (
                            <td className="hidden px-4 py-3 text-right font-mono text-ink-400 md:table-cell">
                              {row.possible_points != null ? `+${formatPoints(row.possible_points)}` : '—'}
                            </td>
                          )}
                          {mode === 'bracket' && (
                            <td className="hidden px-4 py-3 text-right font-mono text-ink-400 md:table-cell">
                              {row.correct_pick_count ?? 0}/{row.scored_pick_count ?? 0}
                            </td>
                          )}
                          {mode === 'bracket' && (
                            <td className="hidden px-4 py-3 lg:table-cell">
                              <AccuracyBar correct={row.correct_pick_count ?? 0} scored={row.scored_pick_count ?? 0} />
                            </td>
                          )}
                          {mode === 'bracket' && (
                            <td className="hidden px-4 py-3 text-right font-mono text-ink-400 lg:table-cell">
                              {row.champions_correct ?? 0}
                            </td>
                          )}
                          <td className="px-4 py-3 text-right">
                            {row.status === 'submitted' || row.status === 'locked' ? (
                              <Badge color="pin">Submitted</Badge>
                            ) : (
                              <Badge color="ink">{row.status ?? 'draft'}</Badge>
                            )}
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            </Card>
          )}

          {(totalPages > 1 || page > 1) && (
            <div className="mt-4 flex items-center justify-between">
              <span className="text-xs text-ink-500">
                Page {page} of {totalPages} · {total} players
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

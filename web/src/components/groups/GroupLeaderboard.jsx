import React from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { Trophy } from 'lucide-react'
import { Avatar, RankChange, Skeleton } from '../ui'
import { cn, formatPoints, pct } from '../../lib/utils'

export function leaderboardRows(data) {
  if (!data) return []
  if (Array.isArray(data)) return data
  return data.entries ?? data.items ?? data.rows ?? []
}

export function rowAccuracy(row) {
  if (row.accuracy != null) return row.accuracy > 1 ? row.accuracy / 100 : row.accuracy
  const scored = row.scored_pick_count ?? row.scored ?? 0
  const correct = row.correct_pick_count ?? row.correct ?? 0
  return scored > 0 ? correct / scored : null
}

/**
 * GroupLeaderboard — ranked table; same column language as the tournament leaderboard.
 * columns: rank (+change) · player · points · possible · accuracy bar · champions
 */
export default function GroupLeaderboard({ rows, loading, selfId, emptyLabel = 'No ranked entries yet.' }) {
  if (loading) {
    return (
      <div className="space-y-2">
        {Array.from({ length: 5 }).map((_, i) => (
          <Skeleton key={i} className="h-14 w-full" />
        ))}
      </div>
    )
  }
  if (!rows?.length) {
    return <p className="rounded-xl border border-dashed border-mat-600 py-10 text-center text-sm text-ink-500">{emptyLabel}</p>
  }
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[560px] border-collapse text-sm">
        <thead>
          <tr className="border-b border-mat-700 text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
            <th className="w-16 px-3 py-2.5">Rank</th>
            <th className="px-3 py-2.5">Player</th>
            <th className="px-3 py-2.5 text-right">Points</th>
            <th className="hidden px-3 py-2.5 text-right sm:table-cell">Possible</th>
            <th className="hidden w-40 px-3 py-2.5 md:table-cell">Accuracy</th>
            <th className="hidden px-3 py-2.5 text-right lg:table-cell">
              <span className="inline-flex items-center gap-1">
                <Trophy size={11} /> Champs
              </span>
            </th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => {
            const u = row.user ?? row
            const isSelf = selfId != null && u.id === selfId
            const acc = rowAccuracy(row)
            const change = row.rank_change ?? (row.prev_rank != null && row.rank != null ? row.prev_rank - row.rank : null)
            return (
              <motion.tr
                key={row.entry_id ?? row.id ?? u.id ?? i}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: Math.min(i * 0.03, 0.4) }}
                className={cn('border-b border-mat-800 last:border-0', isSelf && 'bg-gold-500/[0.06]')}
              >
                <td className="px-3 py-3">
                  <span className="flex items-center gap-1.5">
                    <span className={cn('font-mono text-base font-bold', row.rank <= 3 ? 'text-gold-400' : 'text-ink-300')}>
                      {row.rank ?? i + 1}
                    </span>
                    <RankChange value={change} />
                  </span>
                </td>
                <td className="px-3 py-3">
                  <Link to={`/users/${u.id}`} className="flex items-center gap-2.5 hover:underline">
                    <Avatar user={u} size="sm" ring={row.rank === 1} />
                    <span className="min-w-0">
                      <span className="block truncate font-semibold text-ink-100">
                        {u.display_name || u.name || u.username}
                        {isSelf && <span className="ml-1.5 text-[10px] font-bold uppercase tracking-wider text-gold-400">You</span>}
                      </span>
                      {u.username && <span className="block truncate text-xs text-ink-500">@{u.username}</span>}
                    </span>
                  </Link>
                </td>
                <td className="px-3 py-3 text-right font-mono text-base font-bold text-ink-100">{formatPoints(row.total_points)}</td>
                <td className="hidden px-3 py-3 text-right font-mono text-sm text-ink-400 sm:table-cell">{formatPoints(row.possible_points)}</td>
                <td className="hidden px-3 py-3 md:table-cell">
                  {acc != null ? (
                    <span className="flex items-center gap-2">
                      <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-mat-700/70">
                        <span className="block h-full rounded-full bg-pin-500" style={{ width: `${acc * 100}%` }} />
                      </span>
                      <span className="w-10 text-right font-mono text-xs font-bold text-pin-400">{pct(acc)}</span>
                    </span>
                  ) : (
                    <span className="text-ink-600">—</span>
                  )}
                </td>
                <td className="hidden px-3 py-3 text-right font-mono text-sm font-bold text-gold-400 lg:table-cell">
                  {row.champions_correct ?? 0}
                </td>
              </motion.tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

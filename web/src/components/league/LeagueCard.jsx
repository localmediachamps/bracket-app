import React from 'react'
import { Link } from 'react-router-dom'
import { ChevronRight, Crown, Users } from 'lucide-react'
import { Badge, Card } from '../ui'
import { cn } from '../../lib/utils'

export const LEAGUE_STATUS_BADGE = {
  forming: { color: 'ink', label: 'Forming' },
  drafting: { color: 'gold', label: 'Drafting' },
  active: { color: 'pin', label: 'Active' },
  completed: { color: 'ink', label: 'Completed' },
}

export function LeagueStatusBadge({ status }) {
  const s = LEAGUE_STATUS_BADGE[status] ?? { color: 'ink', label: status }
  return <Badge color={s.color}>{s.label}</Badge>
}

/** row shape from GET /leagues: { league, role, status, wins, losses, points_for } */
export default function LeagueCard({ row, className }) {
  const league = row.league ?? row
  const isOwner = row.role === 'owner'
  const pending = row.status === 'invited'
  return (
    <Link to={`/leagues/${league.id}`} className={cn('block focus:outline-none', className)}>
      <Card hover className="group flex h-full items-center gap-3 p-4">
        <span
          aria-hidden
          className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl border border-mat-600 bg-mat-800 text-2xl"
        >
          {league.avatar_emoji || '🤼'}
        </span>
        <span className="min-w-0 flex-1">
          <span className="flex items-center gap-2">
            <span className="truncate text-sm font-bold text-ink-100">{league.name}</span>
            {isOwner && (
              <span className="inline-flex shrink-0 items-center gap-1 rounded-full bg-gold-500/12 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-gold-400">
                <Crown size={10} /> Owner
              </span>
            )}
          </span>
          <span className="mt-1 flex flex-wrap items-center gap-x-2.5 gap-y-1">
            <LeagueStatusBadge status={league.status} />
            {pending && <Badge color="blood">Invite pending</Badge>}
            <span className="inline-flex items-center gap-1 text-xs text-ink-500">
              <Users size={12} />
              {league.member_count ?? 0}
              {league.member_limit ? `/${league.member_limit}` : ''}
            </span>
          </span>
          {!pending && (row.wins != null || row.losses != null) && (
            <span className="mt-1 block text-xs text-ink-500">
              {row.wins ?? 0}-{row.losses ?? 0}
            </span>
          )}
        </span>
        <ChevronRight size={18} className="shrink-0 text-ink-600 transition-all group-hover:translate-x-0.5 group-hover:text-gold-400" />
      </Card>
    </Link>
  )
}

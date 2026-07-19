import React from 'react'
import { Link } from 'react-router-dom'
import { ChevronRight, Crown, Users } from 'lucide-react'
import { Badge, Card } from '../ui'
import { cn, plural } from '../../lib/utils'

export const PRIVACY_BADGE = {
  public: { color: 'pin', label: 'Public' },
  unlisted: { color: 'ink', label: 'Unlisted' },
  private: { color: 'gold', label: 'Private' },
}

export function PrivacyBadge({ privacy }) {
  const p = PRIVACY_BADGE[privacy] ?? { color: 'ink', label: privacy ?? 'Private' }
  return <Badge color={p.color}>{p.label}</Badge>
}

/**
 * GroupCard — emoji avatar, name, privacy, members, tournament, owner badge, chevron.
 * `compact` renders a narrower card for horizontal scroll rows (Dashboard).
 */
export default function GroupCard({ group, mine, compact, className }) {
  const tournamentName = group.tournament?.name ?? group.tournament_name
  return (
    <Link to={`/groups/${group.id}`} className={cn('block focus:outline-none', compact && 'w-60 shrink-0 snap-start', className)}>
      <Card hover className="group flex h-full items-center gap-3 p-4">
        <span
          aria-hidden
          className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl border border-mat-600 bg-mat-800 text-2xl"
        >
          {group.avatar_emoji || '🤼'}
        </span>
        <span className="min-w-0 flex-1">
          <span className="flex items-center gap-2">
            <span className="truncate text-sm font-bold text-ink-100">{group.name}</span>
            {mine && (
              <span className="inline-flex shrink-0 items-center gap-1 rounded-full bg-gold-500/12 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-gold-400">
                <Crown size={10} /> Owner
              </span>
            )}
          </span>
          <span className="mt-1 flex flex-wrap items-center gap-x-2.5 gap-y-1">
            <PrivacyBadge privacy={group.privacy} />
            <span className="inline-flex items-center gap-1 text-xs text-ink-500">
              <Users size={12} />
              {group.member_count ?? 0}
              {group.member_limit ? `/${group.member_limit}` : ''}
            </span>
          </span>
          {tournamentName && <span className="mt-1 block truncate text-xs text-ink-500">{tournamentName}</span>}
        </span>
        <ChevronRight size={18} className="shrink-0 text-ink-600 transition-all group-hover:translate-x-0.5 group-hover:text-gold-400" />
      </Card>
    </Link>
  )
}

/** tiny helper used across group pages */
export function memberCountLabel(group) {
  return plural(group.member_count ?? 0, 'member')
}

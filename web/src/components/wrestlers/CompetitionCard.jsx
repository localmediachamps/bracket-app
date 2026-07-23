import React, { useState } from 'react'
import { ChevronDown, Swords } from 'lucide-react'
import { cn } from '../../lib/utils'

// Shared "quick stats" display for a wrestler - record + an expandable list
// of notable results against currently-ranked opponents. Backed by
// functions/utils/build_wrestler_competition_card.xs's response shape, used
// anywhere a manager needs to research a wrestler before acting (waiver
// wire, trade center) - same idea as the head-to-head accordion on the
// Rankings page, just wrapped for reuse outside a ranked list.
export default function CompetitionCard({ card, actions }) {
  const [expanded, setExpanded] = useState(false)
  if (!card) return null
  const hasRecord = (card.wins ?? 0) > 0 || (card.losses ?? 0) > 0
  const h2h = card.notable_matches ?? []

  return (
    <div className="rounded-lg border border-mat-700 bg-mat-800">
      <div className="flex items-center justify-between gap-3 p-3">
        <button
          type="button"
          className="flex min-w-0 flex-1 items-center gap-1.5 text-left"
          onClick={() => setExpanded((e) => !e)}
          disabled={h2h.length === 0}
        >
          {h2h.length > 0 && <ChevronDown size={14} className={cn('shrink-0 text-ink-500 transition-transform', expanded && 'rotate-180')} />}
          <div className="min-w-0">
            <div className="truncate text-sm font-semibold text-ink-100">
              {card.display_name}
              {card.weight != null && <span className="ml-2 text-xs text-ink-500">{card.weight} lbs</span>}
            </div>
            <div className="flex flex-wrap items-center gap-x-2 text-xs text-ink-500">
              {card.team_name && <span className="truncate">{card.team_name}</span>}
              {hasRecord && (
                <span className="shrink-0 font-mono text-ink-400">
                  {card.wins}-{card.losses}
                  {h2h.length > 0 && (
                    <span className="ml-1.5 inline-flex items-center gap-0.5 text-pin-400">
                      <Swords size={10} /> {h2h.length}
                    </span>
                  )}
                </span>
              )}
            </div>
          </div>
        </button>
        {actions}
      </div>

      {expanded && h2h.length > 0 && (
        <div className="space-y-1.5 border-t border-mat-700 px-3 py-2.5">
          <p className="mb-1 text-[10px] font-bold uppercase tracking-wider text-ink-600">Vs. currently-ranked wrestlers — most recent first</p>
          {h2h.map((m, i) => (
            <div key={i} className="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs">
              <span className={cn('font-bold', m.is_winner ? 'text-pin-400' : 'text-blood-400')}>{m.is_winner ? 'W' : 'L'}</span>
              <span className="text-ink-200">
                vs #{m.opponent_rank} {m.opponent_name}
              </span>
              <span className="text-ink-500">
                {m.victory_type}
                {m.score ? ` ${m.score}` : ''}
              </span>
              <span className="text-ink-600">
                {m.occurred_at ? new Date(m.occurred_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }) : ''}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

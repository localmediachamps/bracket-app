import React, { useState } from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Crown, Swords, ChevronDown, PencilLine } from 'lucide-react'
import { api } from '../lib/api'
import { Button, Card } from '../components/ui'
import { cn } from '../lib/utils'

const WEIGHTS = ['125', '133', '141', '149', '157', '165', '174', '184', '197', '285']
const DEFAULT_SEASON_YEAR = 2027

export default function Rankings() {
  const [weight, setWeight] = useState('125')
  const [seasonYear] = useState(DEFAULT_SEASON_YEAR)
  const [expanded, setExpanded] = useState(() => new Set())

  const { data, isLoading } = useQuery({
    queryKey: ['rankings', weight, seasonYear],
    queryFn: () => api.rankings({ weight: Number(weight), season_year: seasonYear }),
  })
  const rows = data?.rankings ?? []

  function toggleExpanded(id) {
    setExpanded((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  return (
    <div className="space-y-6 py-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="flex items-center gap-2 font-display text-2xl uppercase tracking-tight text-ink-100">
            <Crown size={22} className="text-gold-400" /> Mat Savvy Rankings
          </h1>
          <p className="mt-1 text-sm text-ink-400">
            Our own top-15 per weight class, backed by real head-to-head results — not a vote, not a poll.
          </p>
        </div>
        <Link to="/my-rankings">
          <Button variant="secondary">
            <PencilLine size={15} /> Build your own rankings
          </Button>
        </Link>
      </div>

      <div className="text-xs font-bold uppercase tracking-wider text-ink-500">
        {seasonYear - 1}-{String(seasonYear).slice(2)} season
      </div>

      <div className="flex gap-1 overflow-x-auto">
        {WEIGHTS.map((w) => (
          <button
            key={w}
            onClick={() => setWeight(w)}
            className={cn(
              'shrink-0 rounded-lg px-4 py-2 text-sm font-bold transition-colors',
              weight === w ? 'bg-gold-500 text-mat-950' : 'bg-mat-800 text-ink-300 hover:bg-mat-750'
            )}
          >
            {w}
          </button>
        ))}
      </div>

      <Card className="p-0">
        <div className="flex items-center justify-between border-b border-mat-700 px-4 py-3">
          <h2 className="flex items-center gap-2 text-sm font-bold uppercase tracking-wide text-ink-200">
            <Crown size={15} className="text-gold-400" /> {weight} lbs — Top {rows.length}
          </h2>
        </div>

        {isLoading ? (
          <div className="p-6 text-sm text-ink-500">Loading…</div>
        ) : rows.length === 0 ? (
          <div className="p-6 text-sm text-ink-500">No Mat Savvy ranking published at {weight} lbs yet.</div>
        ) : (
          <ul>
            {rows.map((r, i) => {
              const h2h = r.head_to_head ?? []
              const isExpanded = expanded.has(r.canonical_wrestler_id)
              return (
                <li key={r.canonical_wrestler_id} className="border-t border-mat-700/60 first:border-t-0">
                  <div className="flex items-center gap-3 px-4 py-2.5">
                    <span className={cn(
                      'w-7 shrink-0 text-center font-mono text-sm font-bold',
                      i < 3 ? 'text-gold-400' : 'text-ink-500'
                    )}>
                      {i + 1}
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-semibold text-ink-100">{r.display_name}</p>
                      {r.team_name && <p className="truncate text-xs text-ink-500">{r.team_name}</p>}
                    </div>
                    {h2h.length > 0 && (
                      <button
                        onClick={() => toggleExpanded(r.canonical_wrestler_id)}
                        className="flex shrink-0 items-center gap-1 rounded-lg px-2 py-1 text-[11px] font-bold text-ink-400 hover:bg-mat-850 hover:text-gold-400"
                        title="Head-to-head vs other top-12 wrestlers"
                      >
                        <Swords size={12} /> {h2h.length}
                        <ChevronDown size={12} className={cn('transition-transform', isExpanded && 'rotate-180')} />
                      </button>
                    )}
                  </div>

                  {isExpanded && h2h.length > 0 && (
                    <div className="border-t border-mat-800 bg-mat-900/40 px-4 py-2.5 pl-14">
                      <p className="mb-1.5 text-[10px] font-bold uppercase tracking-wider text-ink-600">
                        Vs. other top-12 wrestlers — most recent first
                      </p>
                      <div className="space-y-1.5">
                        {h2h.map((m, mi) => (
                          <div key={mi} className="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs">
                            <span className={cn('font-bold', m.is_winner ? 'text-pin-400' : 'text-blood-400')}>
                              {m.is_winner ? 'W' : 'L'}
                            </span>
                            <span className="text-ink-200">vs #{m.opponent_rank} {m.opponent_name}</span>
                            <span className="text-ink-500">
                              {m.victory_type}{m.score ? ` ${m.score}` : ''}
                            </span>
                            <span className="text-ink-600">
                              {m.occurred_at ? new Date(m.occurred_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }) : ''}
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </li>
              )
            })}
          </ul>
        )}
      </Card>
    </div>
  )
}

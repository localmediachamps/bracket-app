import React, { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Lock, Percent, Crown, Flame, Scale } from 'lucide-react'
import { api } from '../../lib/api'
import { Card, EmptyState, Skeleton } from '../ui'
import { cn } from '../../lib/utils'
import { matchSides, championPicks } from './helpers'
import { ErrorState } from './Feedback'

const GOLD_SHADES = ['#E8AE2E', '#C08F1E', '#8F6A14', '#F5C44F', '#FFD87A']
const OTHER_SHADE = '#34343D'

function LockState() {
  return (
    <EmptyState
      icon={<Lock size={22} />}
      title="Revealed when picks lock"
      body="Champion percentages and match-by-match pick heat unlock for everyone the moment predictions close."
    />
  )
}

/** Horizontal stacked bar of champion pick distribution for one weight. */
function ChampionCard({ label, picks }) {
  const sorted = [...picks].sort((a, b) => (b.pct ?? 0) - (a.pct ?? 0))
  const top = sorted.slice(0, 5)
  const restPct = Math.max(0, 100 - top.reduce((a, p) => a + p.pct, 0))
  const segs = restPct > 0.5 ? [...top, { name: 'Everyone else', pct: restPct, other: true }] : top
  const leader = sorted[0]
  return (
    <Card className="p-5">
      <div className="mb-3 flex items-baseline justify-between gap-2">
        <h3 className="font-display text-sm uppercase tracking-wide text-ink-100">{label}</h3>
        {leader && (
          <span className="truncate text-xs text-ink-500">
            Favorite: <span className="font-bold text-gold-400">{leader.name}</span> {Math.round(leader.pct)}%
          </span>
        )}
      </div>
      <div
        className="flex h-9 overflow-hidden rounded-lg border border-mat-700"
        role="img"
        aria-label={`Champion pick distribution for ${label}. Most picked: ${leader?.name ?? 'none'} at ${Math.round(leader?.pct ?? 0)} percent.`}
      >
        {segs.map((p, i) =>
          p.pct > 0 ? (
            <div
              key={p.id ?? p.name ?? i}
              title={`${p.name} — ${Math.round(p.pct)}%`}
              className="h-full border-r border-mat-950/40 transition-all last:border-r-0"
              style={{ width: `${p.pct}%`, backgroundColor: p.other ? OTHER_SHADE : GOLD_SHADES[i % GOLD_SHADES.length] }}
            />
          ) : null
        )}
      </div>
      <ul className="mt-3 space-y-1.5">
        {top.slice(0, 4).map((p, i) => (
          <li key={p.id ?? p.name ?? i} className="flex items-center gap-2.5 text-xs">
            <span className="h-2.5 w-2.5 shrink-0 rounded-sm" style={{ backgroundColor: GOLD_SHADES[i % GOLD_SHADES.length] }} />
            <span className="w-5 shrink-0 font-mono text-[10px] font-bold text-ink-500">{p.seed ?? '–'}</span>
            <span className="min-w-0 flex-1 truncate font-semibold text-ink-200">
              {p.name}
              {p.school && <span className="ml-1.5 font-normal text-ink-500">{p.school}</span>}
            </span>
            <span className="font-mono font-bold text-gold-400">{Math.round(p.pct)}%</span>
            {p.count > 0 && <span className="font-mono text-[10px] text-ink-600">({p.count})</span>}
          </li>
        ))}
        {restPct > 0.5 && (
          <li className="flex items-center gap-2.5 text-xs text-ink-500">
            <span className="h-2.5 w-2.5 shrink-0 rounded-sm" style={{ backgroundColor: OTHER_SHADE }} />
            <span className="w-5 shrink-0" />
            <span className="min-w-0 flex-1 truncate">Everyone else</span>
            <span className="font-mono">{Math.round(restPct)}%</span>
          </li>
        )}
      </ul>
    </Card>
  )
}

function SplitRow({ match, weightLabel }) {
  const [a, b] = matchSides(match)
  if (a.pct == null || b.pct == null) return null
  const aPct = Math.round(a.pct)
  const bPct = Math.round(b.pct)
  return (
    <div className="flex items-center gap-3 border-t border-mat-700/60 px-4 py-3 first:border-t-0">
      <div className="w-24 shrink-0">
        <p className="truncate text-[10px] font-bold uppercase tracking-wider text-ink-500">{match.round_label ?? 'Match'}</p>
        <p className="font-mono text-[10px] text-ink-600">
          {weightLabel ? `${weightLabel} · ` : ''}#{match.match_number ?? match.id}
        </p>
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline justify-between gap-2 text-xs">
          <span className="truncate font-semibold text-ink-100">{a.name}</span>
          <span className="shrink-0 font-mono font-bold text-gold-400">{aPct}%</span>
        </div>
        <div className="my-1 h-1.5 overflow-hidden rounded-full bg-mat-700">
          <div className="h-full rounded-full bg-gold-500" style={{ width: `${aPct}%` }} />
        </div>
        <div className="flex items-baseline justify-between gap-2 text-xs">
          <span className="truncate text-ink-400">{b.name}</span>
          <span className="shrink-0 font-mono text-ink-500">{bPct}%</span>
        </div>
      </div>
    </div>
  )
}

/**
 * PickPopularityPanel — per-weight champion pick distribution + per-match heat.
 * Gated server-side (403) until the tournament locks (or show_pick_percentages).
 */
export default function PickPopularityPanel({ tournament, weights }) {
  const gated = tournament.status === 'open' && !tournament.show_pick_percentages
  const [view, setView] = useState('champions')

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['pick-popularity', tournament.id],
    queryFn: () => api.pickPopularity(tournament.id),
    enabled: !gated,
    staleTime: 60000,
    retry: (count, e) => (e?.status === 403 ? false : count < 2),
  })

  const championGroups = useMemo(() => {
    const groups = data?.champions ?? data?.champion_picks ?? []
    return groups.map((g, i) => {
      const wc = weights.find((w) => w.id === g.weight_class_id)
      const label = g.weight != null ? `${g.weight} lbs` : g.name ?? g.weight_name ?? wc?.name ?? (wc?.weight != null ? `${wc.weight} lbs` : `Weight ${i + 1}`)
      return { key: g.weight_class_id ?? label, label, picks: championPicks(g) }
    })
  }, [data, weights])

  const { chalk, tossups } = useMemo(() => {
    const matches = (data?.matches ?? data?.match_picks ?? [])
      .map((m) => {
        const [a, b] = matchSides(m)
        if (a.pct == null || b.pct == null) return null
        return { m, spread: Math.abs(a.pct - b.pct) }
      })
      .filter(Boolean)
    const bySpread = [...matches].sort((x, y) => y.spread - x.spread)
    return {
      chalk: bySpread.slice(0, 5).map((x) => x.m),
      tossups: [...matches].sort((x, y) => x.spread - y.spread).slice(0, 5).map((x) => x.m),
    }
  }, [data])

  const weightLabelFor = (m) => {
    const wc = weights.find((w) => w.id === m.weight_class_id)
    return wc ? `${wc.weight ?? wc.name}` : m.weight != null ? `${m.weight}` : null
  }

  if (gated || error?.status === 403) return <LockState />

  if (isLoading) {
    return (
      <div className="grid gap-4 lg:grid-cols-2" aria-busy="true" aria-label="Loading pick percentages">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} className="h-56 w-full" />
        ))}
      </div>
    )
  }

  if (isError) return <ErrorState error={error} onRetry={refetch} title="Pick percentages failed to load" />

  const hasChampions = championGroups.some((g) => g.picks.length)
  const hasMatches = chalk.length > 0 || tossups.length > 0

  if (!hasChampions && !hasMatches) {
    return <EmptyState icon={<Percent size={22} />} title="No pick data yet" body="Percentages will fill in as players submit their picks." />
  }

  return (
    <div>
      <div className="mb-5 inline-flex items-center gap-1 rounded-lg border border-mat-700 bg-mat-850 p-1" role="tablist" aria-label="Pick popularity view">
        {[
          { key: 'champions', label: 'Champions', icon: Crown },
          { key: 'matches', label: 'Match heat', icon: Flame },
        ].map((v) => (
          <button
            key={v.key}
            role="tab"
            aria-selected={view === v.key}
            onClick={() => setView(v.key)}
            className={cn(
              'flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-bold transition-colors',
              view === v.key ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200'
            )}
          >
            <v.icon size={13} /> {v.label}
          </button>
        ))}
      </div>

      {view === 'champions' ? (
        hasChampions ? (
          <div className="grid gap-4 lg:grid-cols-2">
            {championGroups.map((g) => (
              <ChampionCard key={g.key} label={g.label} picks={g.picks} />
            ))}
          </div>
        ) : (
          <EmptyState icon={<Crown size={22} />} title="No champion picks yet" body="Champion distributions appear once entries are submitted." />
        )
      ) : hasMatches ? (
        <div className="grid gap-4 lg:grid-cols-2">
          <Card className="overflow-hidden">
            <div className="flex items-center gap-2 border-b border-mat-700 px-4 py-3">
              <Flame size={14} className="text-blood-400" />
              <h3 className="font-display text-xs uppercase tracking-wide text-ink-100">Chalk — most lopsided</h3>
            </div>
            {chalk.map((m) => (
              <SplitRow key={m.id ?? m.match_id} match={m} weightLabel={weightLabelFor(m)} />
            ))}
          </Card>
          <Card className="overflow-hidden">
            <div className="flex items-center gap-2 border-b border-mat-700 px-4 py-3">
              <Scale size={14} className="text-pin-400" />
              <h3 className="font-display text-xs uppercase tracking-wide text-ink-100">Toss-ups — closest splits</h3>
            </div>
            {tossups.map((m) => (
              <SplitRow key={m.id ?? m.match_id} match={m} weightLabel={weightLabelFor(m)} />
            ))}
          </Card>
        </div>
      ) : (
        <EmptyState icon={<Flame size={22} />} title="No match data yet" body="Per-match pick heat appears once entries are submitted." />
      )}
    </div>
  )
}

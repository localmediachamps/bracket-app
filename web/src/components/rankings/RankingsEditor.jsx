import React, { useEffect, useMemo, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { GripVertical, Search, Trash2, Save, Crown, ChevronDown, Swords, AlertTriangle } from 'lucide-react'
import { toast } from '../../lib/store'
import { Button, Card, Select } from '../ui'
import { cn } from '../../lib/utils'

const WEIGHTS = ['125', '133', '141', '149', '157', '165', '174', '184', '197', '285']
const DEFAULT_SEASON_YEAR = 2027

function ordinal(n) {
  const s = ['th', 'st', 'nd', 'rd']
  const v = n % 100
  return n + (s[(v - 20) % 10] || s[v] || s[0])
}

// Shared by the admin Mat Savvy Rankings page and the per-user "My Rankings"
// page - same drag-to-reorder list + smart "who to add" pool + top-12
// head-to-head justification, parameterized by which endpoints back it.
export default function RankingsEditor({
  queryKeyPrefix,
  getRankings,
  getPool,
  saveRankings,
  title,
  subtitle,
  poolTitle,
  emptyBody,
}) {
  const qc = useQueryClient()
  const [weight, setWeight] = useState('125')
  const [seasonYear, setSeasonYear] = useState(DEFAULT_SEASON_YEAR)
  const [rows, setRows] = useState(null)
  const [dragIndex, setDragIndex] = useState(null)
  const [q, setQ] = useState('')
  const [qDebounced, setQDebounced] = useState('')
  const [saving, setSaving] = useState(false)
  const [expanded, setExpanded] = useState(() => new Set())

  function toggleExpanded(id) {
    setExpanded((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  useEffect(() => {
    const t = setTimeout(() => setQDebounced(q.trim()), 300)
    return () => clearTimeout(t)
  }, [q])

  const { data, isLoading } = useQuery({
    queryKey: [queryKeyPrefix, weight, seasonYear],
    queryFn: () => getRankings({ weight: Number(weight), season_year: seasonYear }),
  })

  useEffect(() => {
    setRows(data?.rankings ?? [])
    setExpanded(new Set())
  }, [data])

  const rankedIds = useMemo(() => new Set((rows ?? []).map((r) => r.canonical_wrestler_id)), [rows])

  const { data: poolData, isLoading: poolLoading } = useQuery({
    queryKey: [`${queryKeyPrefix}-pool`, weight, seasonYear, qDebounced],
    queryFn: () => getPool({ weight: Number(weight), season_year: seasonYear, q: qDebounced || undefined }),
  })
  const pool = (poolData?.items ?? []).filter((w) => !rankedIds.has(w.id)).slice(0, 30)

  function addWrestler(w) {
    setRows((prev) => [...(prev ?? []), { canonical_wrestler_id: w.id, display_name: w.display_name, team_name: w.current_team?.name ?? null }])
  }

  function removeWrestler(idx) {
    setRows((prev) => prev.filter((_, i) => i !== idx))
  }

  function onDragStart(idx) {
    setDragIndex(idx)
  }
  function onDragOver(e, idx) {
    e.preventDefault()
    if (dragIndex === null || dragIndex === idx) return
    setRows((prev) => {
      const next = [...prev]
      const [moved] = next.splice(dragIndex, 1)
      next.splice(idx, 0, moved)
      return next
    })
    setDragIndex(idx)
  }
  function onDragEnd() {
    setDragIndex(null)
  }

  async function save() {
    setSaving(true)
    try {
      await saveRankings(Number(weight), {
        season_year: seasonYear,
        canonical_wrestler_ids: (rows ?? []).map((r) => r.canonical_wrestler_id),
      })
      toast.success(`${weight} lbs rankings saved`)
      qc.invalidateQueries({ queryKey: [queryKeyPrefix, weight, seasonYear] })
    } catch (err) {
      toast.error('Could not save rankings', { body: err.message })
    } finally {
      setSaving(false)
    }
  }

  return (
    <div>
      <h1 className="font-display text-2xl text-ink-50">{title}</h1>
      <p className="mt-1 text-sm text-ink-400">{subtitle}</p>

      <div className="mt-5 flex flex-wrap items-center gap-3">
        <Select value={seasonYear} onChange={(e) => setSeasonYear(Number(e.target.value))} className="w-auto">
          <option value={DEFAULT_SEASON_YEAR}>{DEFAULT_SEASON_YEAR - 1}-{String(DEFAULT_SEASON_YEAR).slice(2)} season</option>
        </Select>
      </div>

      <div className="mt-4 flex gap-1 overflow-x-auto">
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

      <div className="mt-5 grid gap-5 lg:grid-cols-[1fr_360px]">
        <Card className="p-0">
          <div className="flex items-center justify-between border-b border-mat-700 px-4 py-3">
            <h2 className="flex items-center gap-2 text-sm font-bold uppercase tracking-wide text-ink-200">
              <Crown size={15} className="text-gold-400" /> {weight} lbs — Top {rows?.length ?? 0}
            </h2>
            <Button size="sm" onClick={save} loading={saving} disabled={isLoading}>
              <Save size={14} /> Save
            </Button>
          </div>

          {isLoading || !rows ? (
            <div className="p-6 text-sm text-ink-500">Loading…</div>
          ) : rows.length === 0 ? (
            <div className="p-6 text-sm text-ink-500">{emptyBody ?? `No one ranked at ${weight} lbs yet — add someone from the roster on the right.`}</div>
          ) : (
            <ul>
              {rows.map((r, i) => {
                const h2h = r.head_to_head ?? []
                const isExpanded = expanded.has(r.canonical_wrestler_id)
                return (
                  <li
                    key={r.canonical_wrestler_id}
                    draggable
                    onDragStart={() => onDragStart(i)}
                    onDragOver={(e) => onDragOver(e, i)}
                    onDragEnd={onDragEnd}
                    className={cn('border-t border-mat-700/60 first:border-t-0', dragIndex === i && 'opacity-40')}
                  >
                    <div className="flex items-center gap-3 px-4 py-2.5">
                      <GripVertical size={15} className="shrink-0 cursor-grab text-ink-600" />
                      <span className="w-7 shrink-0 font-mono text-sm font-bold text-ink-500">{i + 1}</span>
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
                      <button
                        onClick={() => removeWrestler(i)}
                        className="shrink-0 rounded-lg p-1.5 text-ink-600 hover:bg-blood-500/10 hover:text-blood-400"
                        aria-label={`Remove ${r.display_name}`}
                      >
                        <Trash2 size={14} />
                      </button>
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

        <Card className="flex max-h-[calc(100vh-96px)] flex-col p-0 lg:sticky lg:top-6">
          <div className="shrink-0 border-b border-mat-700 px-4 py-3">
            <h2 className="mb-2 text-sm font-bold uppercase tracking-wide text-ink-200">{poolTitle ?? `Add from ${weight} lbs roster`}</h2>
            <div className="relative">
              <Search size={14} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-500" />
              <input
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder="Search wrestlers at this weight…"
                className="w-full rounded-lg border border-mat-700 bg-mat-850 py-1.5 pl-8 pr-3 text-sm text-ink-100 placeholder:text-ink-600 focus:border-gold-500/50 focus:outline-none"
              />
            </div>
          </div>
          <div className="min-h-0 flex-1 overflow-y-auto">
            {poolLoading ? (
              <div className="p-4 text-sm text-ink-500">Loading…</div>
            ) : pool.length === 0 ? (
              <div className="p-4 text-sm text-ink-500">No unranked wrestlers found at {weight} lbs.</div>
            ) : (
              pool.map((w) => (
                <button
                  key={w.id}
                  onClick={() => addWrestler(w)}
                  className="flex w-full items-start gap-3 border-t border-mat-700/60 px-4 py-2.5 text-left first:border-t-0 hover:bg-mat-800/50"
                >
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ink-100">{w.display_name}</p>
                    <p className="truncate text-xs text-ink-500">
                      {w.current_team?.name ?? 'Unknown school'}
                      {w.record_season && ` · ${w.record_wins}-${w.record_losses} (${w.record_season})`}
                    </p>
                    {w.ranked_elsewhere && (
                      <p className="mt-1 flex items-center gap-1 truncate text-[11px] font-bold text-blood-400">
                        <AlertTriangle size={11} className="shrink-0" />
                        Already ranked {ordinal(w.ranked_elsewhere.rank)} at {w.ranked_elsewhere.weight} lbs
                      </p>
                    )}
                    {w.has_beaten_ranked && (
                      <p className="mt-1 truncate text-[11px] font-bold text-pin-400">
                        Beat {w.wins_over_ranked[0].opponent_name} (#{w.wins_over_ranked[0].opponent_rank})
                        {w.wins_over_ranked.length > 1 && ` +${w.wins_over_ranked.length - 1} more`}
                      </p>
                    )}
                  </div>
                  <span className="shrink-0 text-xs font-bold text-gold-400">+ Add</span>
                </button>
              ))
            )}
          </div>
        </Card>
      </div>
    </div>
  )
}

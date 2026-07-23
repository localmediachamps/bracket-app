import React, { useEffect, useMemo, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { GripVertical, Search, Trash2, Save, Crown } from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Button, Card, Select } from '../../components/ui'
import { cn } from '../../lib/utils'

const WEIGHTS = ['125', '133', '141', '149', '157', '165', '174', '184', '197', '285']
const DEFAULT_SEASON_YEAR = 2027

export default function AdminRankings() {
  const qc = useQueryClient()
  const [weight, setWeight] = useState('125')
  const [seasonYear, setSeasonYear] = useState(DEFAULT_SEASON_YEAR)
  const [rows, setRows] = useState(null) // local editable copy: [{canonical_wrestler_id, display_name, team_name}]
  const [dragIndex, setDragIndex] = useState(null)
  const [q, setQ] = useState('')
  const [qDebounced, setQDebounced] = useState('')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    const t = setTimeout(() => setQDebounced(q.trim()), 300)
    return () => clearTimeout(t)
  }, [q])

  const { data, isLoading } = useQuery({
    queryKey: ['admin-rankings', weight, seasonYear],
    queryFn: () => api.adminRankings({ weight: Number(weight), season_year: seasonYear }),
  })

  useEffect(() => {
    setRows(data?.rankings ?? [])
  }, [data])

  const rankedIds = useMemo(() => new Set((rows ?? []).map((r) => r.canonical_wrestler_id)), [rows])

  const { data: poolData, isLoading: poolLoading } = useQuery({
    queryKey: ['admin-rankings-pool', weight, qDebounced],
    queryFn: () => api.wrestlerLibrary({ weight_class: weight, q: qDebounced || undefined, per: 20 }),
  })
  const pool = (poolData?.items ?? []).filter((w) => !rankedIds.has(w.id))

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
      await api.saveAdminRankings(Number(weight), {
        season_year: seasonYear,
        canonical_wrestler_ids: (rows ?? []).map((r) => r.canonical_wrestler_id),
      })
      toast.success(`${weight} lbs rankings saved`)
      qc.invalidateQueries({ queryKey: ['admin-rankings', weight, seasonYear] })
    } catch (err) {
      toast.error('Could not save rankings', { body: err.message })
    } finally {
      setSaving(false)
    }
  }

  return (
    <div>
      <h1 className="font-display text-2xl text-ink-50">Composite Rankings</h1>
      <p className="mt-1 text-sm text-ink-400">
        Manually managed per weight class — drag to reorder, search the roster to add someone, remove anyone who shouldn't be ranked.
      </p>

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
            <div className="p-6 text-sm text-ink-500">No one ranked at {weight} lbs yet — add someone from the roster on the right.</div>
          ) : (
            <ul>
              {rows.map((r, i) => (
                <li
                  key={r.canonical_wrestler_id}
                  draggable
                  onDragStart={() => onDragStart(i)}
                  onDragOver={(e) => onDragOver(e, i)}
                  onDragEnd={onDragEnd}
                  className={cn(
                    'flex items-center gap-3 border-t border-mat-700/60 px-4 py-2.5 first:border-t-0',
                    dragIndex === i && 'opacity-40'
                  )}
                >
                  <GripVertical size={15} className="shrink-0 cursor-grab text-ink-600" />
                  <span className="w-7 shrink-0 font-mono text-sm font-bold text-ink-500">{i + 1}</span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ink-100">{r.display_name}</p>
                    {r.team_name && <p className="truncate text-xs text-ink-500">{r.team_name}</p>}
                  </div>
                  <button
                    onClick={() => removeWrestler(i)}
                    className="shrink-0 rounded-lg p-1.5 text-ink-600 hover:bg-blood-500/10 hover:text-blood-400"
                    aria-label={`Remove ${r.display_name}`}
                  >
                    <Trash2 size={14} />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card className="p-0">
          <div className="border-b border-mat-700 px-4 py-3">
            <h2 className="mb-2 text-sm font-bold uppercase tracking-wide text-ink-200">Add from {weight} lbs roster</h2>
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
          <div className="max-h-[520px] overflow-y-auto">
            {poolLoading ? (
              <div className="p-4 text-sm text-ink-500">Loading…</div>
            ) : pool.length === 0 ? (
              <div className="p-4 text-sm text-ink-500">No unranked wrestlers found at {weight} lbs.</div>
            ) : (
              pool.map((w) => (
                <button
                  key={w.id}
                  onClick={() => addWrestler(w)}
                  className="flex w-full items-center gap-3 border-t border-mat-700/60 px-4 py-2.5 text-left first:border-t-0 hover:bg-mat-800/50"
                >
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ink-100">{w.display_name}</p>
                    <p className="truncate text-xs text-ink-500">{w.current_team?.name ?? 'Unknown school'}</p>
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

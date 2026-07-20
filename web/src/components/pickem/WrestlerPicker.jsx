import React, { useMemo, useState } from 'react'
import { AlertTriangle, Check, Search, Sparkles } from 'lucide-react'
import { cn } from '../../lib/utils'
import { Badge, Button, Modal, Skeleton } from '../ui'

const SORTS = [
  { key: 'seed', label: 'Seed' },
  { key: 'cost', label: 'Cost' },
  { key: 'name', label: 'Name' },
]

/**
 * WrestlerPicker — modal picker for one weight class: search, sort controls,
 * and the competitor table (seed, name, school, record, cost, select).
 * Wrestlers picked in other weights get a tag but stay selectable.
 */
export default function WrestlerPicker({
  open,
  onClose,
  weightClass,
  competitors,
  loading,
  error,
  onRetry,
  selectedId,
  picks,
  weightClasses,
  seedCosts,
  recommendedId,
  onSelect,
}) {
  const [q, setQ] = useState('')
  const [sort, setSort] = useState('seed')

  const costOf = (w) => seedCosts?.[String(w?.seed)] ?? seedCosts?.default ?? 0

  const pickedElsewhere = useMemo(() => {
    const m = new Map()
    for (const wc of weightClasses ?? []) {
      const wid = picks?.[wc.id]
      if (wid != null && wc.id !== weightClass?.id) m.set(wid, wc.weight ?? wc.name)
    }
    return m
  }, [picks, weightClasses, weightClass])

  const rows = useMemo(() => {
    let list = [...(competitors ?? [])]
    const needle = q.trim().toLowerCase()
    if (needle) list = list.filter((c) => `${c.name ?? ''} ${c.school ?? ''}`.toLowerCase().includes(needle))
    list.sort((a, b) => {
      if (sort === 'cost') return costOf(b) - costOf(a) || (a.seed ?? 999) - (b.seed ?? 999)
      if (sort === 'name') return (a.name ?? '').localeCompare(b.name ?? '')
      return (a.seed ?? 999) - (b.seed ?? 999)
    })
    return list
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [competitors, q, sort, seedCosts])

  const label = weightClass?.weight ?? weightClass?.name ?? ''

  return (
    <Modal open={open} onClose={onClose} title={`Pick your ${label} wrestler`} wide>
      {/* search + sort */}
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search size={15} className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-500" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search name or school…"
            aria-label="Search wrestlers"
            className="h-11 w-full rounded-xl border border-mat-600 bg-mat-800 pl-10 pr-3.5 text-sm text-ink-100 placeholder:text-ink-600 transition-colors hover:border-mat-500 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
          />
        </div>
        <div className="flex items-center gap-1 rounded-lg border border-mat-700 bg-mat-800 p-1" role="group" aria-label="Sort wrestlers">
          {SORTS.map((s) => (
            <button
              key={s.key}
              onClick={() => setSort(s.key)}
              aria-pressed={sort === s.key}
              className={cn(
                'rounded-md px-3 py-1.5 text-xs font-bold transition-colors',
                sort === s.key ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200'
              )}
            >
              {s.label}
            </button>
          ))}
        </div>
      </div>

      {/* table */}
      {loading ? (
        <div className="space-y-2">
          {[...Array(6)].map((_, i) => (
            <Skeleton key={i} className="h-12 w-full" />
          ))}
        </div>
      ) : error ? (
        <div className="flex flex-col items-center gap-3 rounded-xl border border-mat-700 bg-mat-900/50 p-8 text-center">
          <AlertTriangle size={20} className="text-blood-400" />
          <p className="text-sm text-ink-400">{error}</p>
          <Button variant="secondary" size="sm" onClick={onRetry}>
            Try again
          </Button>
        </div>
      ) : rows.length === 0 ? (
        <div className="rounded-xl border border-dashed border-mat-600 bg-mat-900/50 p-8 text-center text-sm text-ink-500">
          {q ? `No wrestlers match “${q}”.` : 'No competitors in this weight class yet.'}
        </div>
      ) : (
        <div className="max-h-[52vh] divide-y divide-mat-700 overflow-y-auto rounded-xl border border-mat-700">
          {rows.map((w) => {
            const elsewhere = pickedElsewhere.get(w.id)
            const isCurrent = w.id === selectedId
            return (
              <div key={w.id} className={cn('flex items-center gap-3 px-3 py-2.5 transition-colors hover:bg-mat-800/60', w.withdrawn && 'opacity-55')}>
                <span className="flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded bg-mat-700 font-mono text-[10px] font-bold text-gold-400">
                  {w.seed ?? '–'}
                </span>
                <span className="min-w-0 flex-1 leading-tight">
                  <span className="flex items-center gap-1.5">
                    <span className="block truncate text-sm font-semibold text-ink-100">{w.name}</span>
                    {recommendedId != null && w.id === recommendedId && (
                      <span
                        className="inline-flex shrink-0 items-center gap-0.5 rounded-full border border-gold-500/40 bg-gold-500/12 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-gold-400"
                        title="Best Scenario's pick for this weight class"
                      >
                        <Sparkles size={9} /> Recommended
                      </span>
                    )}
                  </span>
                  <span className="block truncate text-[11px] text-ink-500">
                    {w.school}
                    {w.record ? ` · ${w.record}` : ''}
                  </span>
                </span>
                {w.withdrawn && (
                  <Badge color="blood" className="hidden sm:inline-flex">
                    WD
                  </Badge>
                )}
                {elsewhere != null && (
                  <span className="hidden shrink-0 rounded-full border border-mat-600 bg-mat-800 px-2 py-0.5 text-[9px] font-bold uppercase tracking-wide text-ink-400 sm:inline-block">
                    Picked @ {elsewhere}
                  </span>
                )}
                <span className="shrink-0 rounded-lg border border-gold-500/30 bg-gold-500/12 px-2 py-1 font-mono text-xs font-bold text-gold-300">
                  {costOf(w)}
                </span>
                {isCurrent ? (
                  <span className="flex w-[74px] shrink-0 items-center justify-center gap-1 rounded-lg border border-pin-500/40 bg-pin-500/10 px-2 py-1.5 text-xs font-bold text-pin-400">
                    <Check size={13} /> Current
                  </span>
                ) : (
                  <Button size="xs" variant="secondary" className="w-[74px] shrink-0" onClick={() => onSelect(w)} aria-label={`Select ${w.name}`}>
                    Select
                  </Button>
                )}
              </div>
            )
          })}
        </div>
      )}
    </Modal>
  )
}

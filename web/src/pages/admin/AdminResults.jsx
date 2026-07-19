import React, { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQueries, useQuery, useQueryClient } from '@tanstack/react-query'
import { AnimatePresence, motion } from 'framer-motion'
import {
  AlertTriangle, Check, ChevronDown, Keyboard, ListChecks, Pencil, RotateCcw, Trophy, X,
} from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Badge, Button, Card, EmptyState, Input, Modal, Skeleton, Textarea } from '../../components/ui'
import { cn, VICTORY_TYPES, victoryLabel } from '../../lib/utils'
import { ConfirmModal, ErrorState, PageHeader, ProgressBar } from '../../components/admin/AdminCommon'
import WeightTabs from '../../components/admin/WeightTabs'
import { errMsg, isDownstreamConflict } from '../../components/admin/adminUtils'

const SECTION_ORDER = { championship: 0, consolation: 1, placement: 2 }
const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'pending', label: 'Pending' },
  { key: 'complete', label: 'Completed' },
]
const isDone = (m) => m.status === 'complete' || m.status === 'corrected'

export default function AdminResults() {
  const { id } = useParams()
  const qc = useQueryClient()
  const [activeWc, setActiveWc] = useState(null)
  const [filter, setFilter] = useState('pending')
  const [expandedId, setExpandedId] = useState(null)
  const [editing, setEditing] = useState(null) // match being corrected
  const [clearing, setClearing] = useState(null) // match being cleared
  const [overrides, setOverrides] = useState({})
  const rowRefs = useRef(new Map())

  const tQ = useQuery({ queryKey: ['admin', 'tournament', id], queryFn: () => api.tournament(id) })
  const tournament = tQ.data?.tournament ?? tQ.data
  const weights = useMemo(
    () =>
      (tQ.data?.weight_classes ?? tournament?.weight_classes ?? [])
        .slice()
        .sort((a, b) => (a.display_order ?? a.weight ?? 0) - (b.display_order ?? b.weight ?? 0)),
    [tQ.data, tournament]
  )
  const wcId = activeWc ?? weights[0]?.id

  /* one bracket query per weight — drives tabs progress + tournament progress */
  const bracketQs = useQueries({
    queries: weights.map((w) => ({
      queryKey: ['admin', 'bracket', id, w.id],
      queryFn: () => api.adminBracketView(id, w.id),
    })),
  })

  const progressByWc = useMemo(() => {
    const m = new Map()
    bracketQs.forEach((q, i) => {
      const matches = q.data?.matches ?? []
      const done = matches.filter(isDone).length
      m.set(weights[i]?.id, { done, total: matches.length })
    })
    return m
  }, [bracketQs, weights])

  const tournamentProgress = useMemo(() => {
    let done = 0
    let total = 0
    for (const p of progressByWc.values()) {
      done += p.done
      total += p.total
    }
    return { done, total, ratio: total ? done / total : 0 }
  }, [progressByWc])

  const activeIdx = weights.findIndex((w) => w.id === wcId)
  const activeQ = bracketQs[activeIdx] ?? { isLoading: true }

  const matches = useMemo(() => {
    const raw = activeQ.data?.matches ?? []
    return raw.map((m) => (overrides[m.id] ? { ...m, ...overrides[m.id] } : m))
  }, [activeQ.data, overrides])

  /* group by round, champ → consolation → placement */
  const groups = useMemo(() => {
    const sorted = [...matches].sort(
      (a, b) =>
        (SECTION_ORDER[a.section] ?? 9) - (SECTION_ORDER[b.section] ?? 9) ||
        (a.round_number ?? 0) - (b.round_number ?? 0) ||
        (a.match_number ?? 0) - (b.match_number ?? 0)
    )
    const out = []
    let cur = null
    for (const m of sorted) {
      const key = `${m.section}-${m.round_number ?? m.round_code}`
      if (!cur || cur.key !== key) {
        cur = { key, label: m.round_label ?? m.round_code, section: m.section, matches: [] }
        out.push(cur)
      }
      cur.matches.push(m)
    }
    return out
  }, [matches])

  const visibleGroups = useMemo(() => {
    if (filter === 'all') return groups
    return groups
      .map((g) => ({
        ...g,
        matches: g.matches.filter((m) => (filter === 'pending' ? !isDone(m) : isDone(m))),
      }))
      .filter((g) => g.matches.length > 0)
  }, [groups, filter])

  const flatVisible = useMemo(() => visibleGroups.flatMap((g) => g.matches), [visibleGroups])

  const wcProgress = progressByWc.get(wcId) ?? { done: 0, total: 0 }

  const invalidateBrackets = () => {
    qc.invalidateQueries({ queryKey: ['admin', 'bracket', id] })
  }

  const setResultMut = useMutation({
    mutationFn: ({ matchId, payload }) => api.adminSetResult(matchId, payload),
    onMutate: ({ matchId, payload }) => {
      setOverrides((o) => ({
        ...o,
        [matchId]: { status: 'complete', winner_competitor_id: payload.winner_wrestler_id, victory_type: payload.victory_type, score: payload.score },
      }))
    },
    onSuccess: (_d, vars) => {
      toast.success('Result saved')
      advanceFrom(vars.matchId)
    },
    onError: (e, vars) => {
      setOverrides((o) => {
        const n = { ...o }
        delete n[vars.matchId]
        return n
      })
      if (e?.status === 409) {
        toast.error('Conflict — data refreshed', { body: errMsg(e, 'This match changed elsewhere. Try again.') })
        invalidateBrackets()
      } else {
        toast.error('Save failed', { body: errMsg(e) })
      }
    },
    onSettled: (_d, _e, vars) => {
      qc.invalidateQueries({ queryKey: ['admin', 'bracket', id, vars.matchWc] })
    },
  })

  const clearMut = useMutation({
    mutationFn: ({ matchId, reason }) => api.adminClearResult(matchId, reason),
    onSuccess: (_d, vars) => {
      toast.success('Result cleared', { body: 'Downstream slots unwound, entries rescored.' })
      setOverrides((o) => ({
        ...o,
        [vars.matchId]: { status: 'pending', winner_competitor_id: null, victory_type: null, score: null },
      }))
      setClearing(null)
      invalidateBrackets()
    },
    onError: (e) => toast.error('Clear failed', { body: errMsg(e) }),
  })

  /* move expansion to the next pending match */
  const advanceFrom = (matchId) => {
    const idx = flatVisible.findIndex((m) => m.id === matchId)
    const next = flatVisible.slice(idx + 1).find((m) => !isDone(m) && !m.is_bye)
    if (next) {
      setExpandedId(next.id)
      requestAnimationFrame(() => {
        rowRefs.current.get(next.id)?.scrollIntoView({ behavior: 'smooth', block: 'center' })
      })
    } else {
      setExpandedId(null)
    }
  }

  if (tQ.isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-9 w-72" />
        <Skeleton className="h-12" />
        <Skeleton className="h-64" />
      </div>
    )
  }
  if (tQ.isError) return <ErrorState error={tQ.error} onRetry={() => tQ.refetch()} title="Couldn't load tournament" />

  const tabsWeights = weights.map((w) => {
    const p = progressByWc.get(w.id)
    return { ...w, progress: p && p.total ? p.done / p.total : undefined }
  })

  return (
    <div className="pb-8">
      <PageHeader
        title="Result Entry"
        sub={`${tournament?.name ?? ''} · ${tournamentProgress.done}/${tournamentProgress.total} matches final`}
        actions={
          <div className="w-40">
            <ProgressBar value={tournamentProgress.ratio} tone={tournamentProgress.ratio >= 1 ? 'pin' : 'gold'} />
            <p className="mt-1 text-right font-mono text-[10px] text-ink-500">{Math.round(tournamentProgress.ratio * 100)}% of tournament</p>
          </div>
        }
      />

      {weights.length === 0 ? (
        <EmptyState
          icon={<ListChecks size={24} />}
          title="No weight classes"
          body="Build the bracket structure first."
          action={<Link to={`/admin/tournaments/${id}/builder`}><Button variant="primary">Open Builder</Button></Link>}
        />
      ) : (
        <>
          <WeightTabs className="mb-3" weights={tabsWeights} activeId={wcId} onChange={(w) => { setActiveWc(w); setExpandedId(null) }} />

          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-1 rounded-lg border border-mat-700 bg-mat-850 p-1" role="tablist" aria-label="Match filter">
              {FILTERS.map((f) => (
                <button
                  key={f.key}
                  role="tab"
                  aria-selected={filter === f.key}
                  onClick={() => setFilter(f.key)}
                  className={cn(
                    'rounded-md px-3 py-1.5 text-xs font-bold transition-colors',
                    filter === f.key ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200'
                  )}
                >
                  {f.label}
                </button>
              ))}
            </div>
            <div className="flex items-center gap-2 text-xs text-ink-500">
              <span className="font-mono font-bold text-ink-300">{wcProgress.done}/{wcProgress.total}</span> final at {weights.find((w) => w.id === wcId)?.weight} lbs
            </div>
          </div>
          <ProgressBar className="mb-5" value={wcProgress.total ? wcProgress.done / wcProgress.total : 0} tone={wcProgress.total && wcProgress.done === wcProgress.total ? 'pin' : 'gold'} />

          {activeQ.isLoading ? (
            <div className="space-y-2">
              <Skeleton className="h-16" /><Skeleton className="h-16" /><Skeleton className="h-16" /><Skeleton className="h-16" />
            </div>
          ) : activeQ.isError ? (
            <ErrorState error={activeQ.error} onRetry={() => activeQ.refetch()} title="Couldn't load matches" />
          ) : matches.length === 0 ? (
            <EmptyState
              icon={<ListChecks size={24} />}
              title="No bracket generated"
              body="Generate this weight's bracket in the Builder before entering results."
              action={<Link to={`/admin/tournaments/${id}/builder`}><Button variant="primary">Open Builder</Button></Link>}
            />
          ) : flatVisible.length === 0 ? (
            <Card className="p-8 text-center">
              <Check size={22} className="mx-auto mb-2 text-pin-400" />
              <p className="text-sm font-semibold text-ink-200">
                {filter === 'pending' ? 'Nothing pending at this weight — nice work.' : 'No matches in this view.'}
              </p>
              {filter === 'pending' && (
                <Button variant="ghost" size="sm" className="mt-3" onClick={() => setFilter('all')}>Show all matches</Button>
              )}
            </Card>
          ) : (
            <div className="space-y-6">
              {visibleGroups.map((g) => {
                const done = g.matches.filter(isDone).length
                return (
                  <section key={g.key}>
                    <h3
                      className={cn(
                        'mb-2 flex items-center gap-2 text-[11px] font-bold uppercase tracking-[0.14em]',
                        g.section === 'championship' ? 'text-gold-400' : g.section === 'placement' ? 'text-gold-500' : 'text-ink-500'
                      )}
                    >
                      {g.section === 'placement' && <Trophy size={11} />}
                      {g.label}
                      <span className="font-mono text-[10px] font-normal text-ink-600">{done}/{g.matches.length}</span>
                    </h3>
                    <div className="space-y-2">
                      {g.matches.map((m) => (
                        <MatchRow
                          key={m.id}
                          ref={(el) => {
                            if (el) rowRefs.current.set(m.id, el)
                            else rowRefs.current.delete(m.id)
                          }}
                          match={m}
                          expanded={expandedId === m.id}
                          onExpand={() => setExpandedId(expandedId === m.id ? null : m.id)}
                          onCollapse={() => setExpandedId(null)}
                          onSave={(payload) => setResultMut.mutate({ matchId: m.id, matchWc: wcId, payload })}
                          saving={setResultMut.isPending && setResultMut.variables?.matchId === m.id}
                          onEdit={() => setEditing(m)}
                          onClear={() => setClearing(m)}
                        />
                      ))}
                    </div>
                  </section>
                )
              })}
            </div>
          )}

          {/* keyboard hint footer */}
          <div className="mt-8 flex items-center justify-center gap-2 text-[11px] text-ink-600">
            <Keyboard size={13} />
            <span>Click a winner → pick victory type → <kbd className="rounded bg-mat-800 px-1.5 py-0.5 font-mono text-[10px] text-ink-300">Enter</kbd> saves & jumps to the next pending match. <kbd className="rounded bg-mat-800 px-1.5 py-0.5 font-mono text-[10px] text-ink-300">Esc</kbd> cancels.</span>
          </div>
        </>
      )}

      {/* correction modal */}
      <CorrectionModal
        match={editing}
        wcId={wcId}
        onClose={() => setEditing(null)}
        onSaved={() => {
          setEditing(null)
          invalidateBrackets()
        }}
      />

      {/* clear confirm */}
      <ConfirmModal
        open={!!clearing}
        onClose={() => setClearing(null)}
        title="Clear result"
        body={
          clearing && (
            <span>
              Clears the result of <strong>{clearing.round_label} #{clearing.match_number}</strong> and unwinds downstream slots (unless those matches are complete). Entries are rescored. A history row is kept.
            </span>
          )
        }
        confirmLabel="Clear result"
        danger
        requireReason
        reasonPlaceholder="Why is this result being cleared?"
        loading={clearMut.isPending}
        onConfirm={(reason) => clearMut.mutate({ matchId: clearing.id, reason })}
      />
    </div>
  )
}

/* ── One match row ──────────────────────────────────── */
const MatchRow = React.forwardRef(function MatchRow({ match, expanded, onExpand, onCollapse, onSave, saving, onEdit, onClear }, ref) {
  const done = isDone(match)
  const top = match.top?.competitor
  const bottom = match.bottom?.competitor

  if (match.is_bye) {
    const comp = top ?? bottom
    return (
      <div ref={ref} className="flex items-center gap-3 rounded-xl border border-mat-700/60 bg-mat-900/40 px-4 py-3 opacity-60">
        <span className="font-mono text-[10px] font-bold text-ink-600">#{match.match_number}</span>
        <span className="bg-mat-stripes rounded px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-ink-500">Bye</span>
        <span className="truncate text-sm text-ink-300">{comp ? `${comp.seed ? `#${comp.seed} ` : ''}${comp.name}` : 'Auto-advance'}</span>
      </div>
    )
  }

  if (done) {
    const winner = match.winner_competitor_id === top?.id ? top : match.winner_competitor_id === bottom?.id ? bottom : null
    const loser = winner === top ? bottom : top
    return (
      <div ref={ref} className="rounded-xl border border-mat-700 bg-mat-850 px-4 py-3">
        <div className="flex items-center gap-3">
          <span className="font-mono text-[10px] font-bold text-ink-600">#{match.match_number}</span>
          <div className="min-w-0 flex-1">
            <p className="flex items-center gap-1.5 text-sm">
              <Check size={14} strokeWidth={3.5} className="shrink-0 text-pin-400" />
              <span className="truncate font-semibold text-pin-300">
                {winner ? `${winner.seed ? `#${winner.seed} ` : ''}${winner.name}` : `Wrestler #${match.winner_competitor_id}`}
              </span>
              {match.status === 'corrected' && <Badge color="gold">Corrected</Badge>}
            </p>
            <p className="mt-0.5 truncate text-xs text-ink-500">
              over {loser ? `${loser.seed ? `#${loser.seed} ` : ''}${loser.name}` : '—'}
              {winner?.school ? ` · ${winner.school}` : ''}
            </p>
          </div>
          <span className="shrink-0 rounded bg-mat-700 px-2 py-1 font-mono text-[11px] font-bold text-pin-400">
            {victoryLabel(match.victory_type)}{match.score ? ` ${match.score}` : ''}
          </span>
          <div className="flex shrink-0 gap-1">
            <button onClick={onEdit} aria-label={`Edit result of match ${match.match_number}`} className="rounded-lg p-2 text-ink-500 transition-colors hover:bg-mat-700 hover:text-gold-400">
              <Pencil size={14} />
            </button>
            <button onClick={onClear} aria-label={`Clear result of match ${match.match_number}`} className="rounded-lg p-2 text-ink-500 transition-colors hover:bg-blood-500/15 hover:text-blood-400">
              <RotateCcw size={14} />
            </button>
          </div>
        </div>
      </div>
    )
  }

  /* pending row */
  return (
    <div ref={ref} className={cn('rounded-xl border bg-mat-850 transition-colors', expanded ? 'border-gold-500/60 shadow-glow-sm' : 'border-mat-700')}>
      <div className="px-3 py-2.5 sm:px-4">
        <div className="mb-2 flex items-center gap-2">
          <span className="font-mono text-[10px] font-bold text-ink-600">#{match.match_number}</span>
          <span className="text-[10px] font-semibold uppercase tracking-wider text-ink-600">{match.round_label}</span>
          {match.status === 'in_progress' && <Badge color="blood" pulse>On the mat</Badge>}
        </div>
        <div className="grid gap-2 sm:grid-cols-2">
          <CompetitorButton comp={top} onClick={onExpand} active={expanded} position="top" />
          <CompetitorButton comp={bottom} onClick={onExpand} active={expanded} position="bottom" />
        </div>
      </div>

      <AnimatePresence>
        {expanded && (
          <ResultForm
            key="form"
            match={match}
            saving={saving}
            onSave={onSave}
            onCancel={onCollapse}
          />
        )}
      </AnimatePresence>
    </div>
  )
})

function CompetitorButton({ comp, onClick, active, position }) {
  if (!comp) {
    return (
      <div className="bg-mat-stripes flex min-h-[52px] items-center justify-center rounded-lg border border-mat-700/70 text-xs font-semibold italic text-ink-600">
        TBD — earlier rounds
      </div>
    )
  }
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={`${comp.name} wins, seed ${comp.seed}, ${comp.school}`}
      className={cn(
        'flex min-h-[52px] items-center gap-2.5 rounded-lg border px-3 py-2 text-left transition-all active:scale-[0.99]',
        active
          ? 'border-gold-500/70 bg-gold-500/10'
          : 'border-mat-600 bg-mat-800 hover:border-gold-500/50 hover:bg-mat-750'
      )}
    >
      <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-mat-700 font-mono text-xs font-bold text-gold-400">
        {comp.seed ?? '–'}
      </span>
      <span className="min-w-0 flex-1 leading-tight">
        <span className="block truncate text-sm font-semibold text-ink-100">{comp.name}</span>
        <span className="block truncate text-[11px] text-ink-500">{comp.school}{comp.record ? ` · ${comp.record}` : ''}</span>
      </span>
      <ChevronDown size={14} className={cn('shrink-0 text-ink-600 transition-transform', active && 'rotate-180 text-gold-400')} />
    </button>
  )
}

/* ── Inline expand: pick winner + victory + score ───── */
function ResultForm({ match, saving, onSave, onCancel }) {
  const top = match.top?.competitor
  const bottom = match.bottom?.competitor
  const [winnerId, setWinnerId] = useState(null)
  const [victory, setVictory] = useState('decision')
  const [score, setScore] = useState('')
  const scoreRef = useRef(null)

  useEffect(() => {
    scoreRef.current?.focus()
  }, [])

  const submit = (e) => {
    e?.preventDefault()
    if (!winnerId || saving) return
    onSave({
      winner_wrestler_id: winnerId,
      victory_type: victory,
      score: score.trim() || undefined,
      expected_version: match.version,
    })
  }

  return (
    <motion.form
      initial={{ height: 0, opacity: 0 }}
      animate={{ height: 'auto', opacity: 1 }}
      exit={{ height: 0, opacity: 0 }}
      transition={{ duration: 0.18 }}
      onSubmit={submit}
      onKeyDown={(e) => e.key === 'Escape' && onCancel()}
      className="overflow-hidden border-t border-mat-700"
    >
      <div className="space-y-3 px-3 py-3 sm:px-4">
        {/* winner quick-pick */}
        <div className="grid gap-2 sm:grid-cols-2" role="radiogroup" aria-label="Winner">
          {[top, bottom].map((c) =>
            c ? (
              <button
                key={c.id}
                type="button"
                role="radio"
                aria-checked={winnerId === c.id}
                onClick={() => setWinnerId(c.id)}
                className={cn(
                  'flex min-h-[44px] items-center gap-2 rounded-lg border px-3 py-1.5 text-left transition-all',
                  winnerId === c.id ? 'border-pin-500 bg-pin-500/15 text-pin-300' : 'border-mat-600 bg-mat-800 text-ink-300 hover:border-mat-500'
                )}
              >
                <span className={cn('flex h-5 w-5 items-center justify-center rounded-full border text-[10px]', winnerId === c.id ? 'border-pin-500 bg-pin-500 text-mat-950' : 'border-mat-600 text-transparent')}>
                  <Check size={11} strokeWidth={4} />
                </span>
                <span className="truncate text-sm font-semibold">#{c.seed} {c.name}</span>
              </button>
            ) : null
          )}
        </div>

        {/* victory type chips */}
        <div className="flex flex-wrap gap-1.5" role="radiogroup" aria-label="Victory type">
          {Object.entries(VICTORY_TYPES).map(([key, v]) => (
            <button
              key={key}
              type="button"
              role="radio"
              aria-checked={victory === key}
              title={v.name}
              onClick={() => setVictory(key)}
              className={cn(
                'min-h-[36px] rounded-lg border px-2.5 font-mono text-xs font-bold transition-colors',
                victory === key ? 'border-gold-500 bg-gold-500 text-mat-950' : 'border-mat-600 bg-mat-800 text-ink-400 hover:border-mat-500 hover:text-ink-200'
              )}
            >
              {v.label}
            </button>
          ))}
        </div>

        {/* score + save */}
        <div className="flex items-center gap-2">
          <div className="w-36">
            <input
              ref={scoreRef}
              value={score}
              onChange={(e) => setScore(e.target.value)}
              placeholder="Score (7-2)"
              aria-label="Score"
              className="h-11 w-full rounded-xl border border-mat-600 bg-mat-800 px-3 font-mono text-sm text-ink-100 placeholder:text-ink-600 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
            />
          </div>
          <Button type="submit" variant="primary" disabled={!winnerId} loading={saving} className="flex-1 sm:flex-none">
            <Check size={15} /> Save result
          </Button>
          <Button type="button" variant="ghost" onClick={onCancel} aria-label="Cancel">
            <X size={15} />
          </Button>
        </div>
      </div>
    </motion.form>
  )
}

/* ── Correction modal ───────────────────────────────── */
function CorrectionModal({ match, wcId, onClose, onSaved }) {
  const qc = useQueryClient()
  const [victory, setVictory] = useState('decision')
  const [score, setScore] = useState('')
  const [reason, setReason] = useState('')
  const [winnerId, setWinnerId] = useState(null)
  const [conflict, setConflict] = useState(null)

  useEffect(() => {
    if (match) {
      setVictory(match.victory_type ?? 'decision')
      setScore(match.score ?? '')
      setReason('')
      setWinnerId(match.winner_competitor_id ?? null)
      setConflict(null)
    }
  }, [match])

  const mut = useMutation({
    mutationFn: () =>
      api.adminSetResult(match.id, {
        winner_wrestler_id: winnerId,
        victory_type: victory,
        score: score.trim() || undefined,
        expected_version: match.version,
        change_reason: reason.trim(),
      }),
    onSuccess: () => {
      toast.success('Correction applied', { body: 'Downstream propagated, entries rescored.' })
      qc.invalidateQueries({ queryKey: ['admin', 'bracket'] })
      onSaved()
    },
    onError: (e) => {
      if (isDownstreamConflict(e)) {
        setConflict(e)
      } else {
        toast.error('Correction failed', { body: errMsg(e) })
      }
    },
  })

  if (!match) return null
  const top = match.top?.competitor
  const bottom = match.bottom?.competitor

  return (
    <Modal open={!!match} onClose={mut.isPending ? undefined : onClose} title={`Correct result — ${match.round_label} #${match.match_number}`}>
      <form
        onSubmit={(e) => {
          e.preventDefault()
          mut.mutate()
        }}
        className="space-y-4"
      >
        <div className="rounded-lg border border-gold-500/30 bg-gold-500/6 px-3 py-2 text-xs text-gold-300">
          Corrections propagate downstream and rescore affected entries. Version <span className="font-mono font-bold">{match.version}</span> is kept in history.
        </div>

        {conflict && (
          <div className="flex items-start gap-2 rounded-lg border border-blood-500/40 bg-blood-500/10 px-3 py-2 text-xs text-blood-300">
            <AlertTriangle size={14} className="mt-0.5 shrink-0" />
            <span>
              <strong>Blocked:</strong> a downstream match is already complete. Correct the downstream matches first (reverse chronological order), then retry this correction.
              {conflict?.payload?.downstream_match_id && <span className="mt-0.5 block font-mono text-[10px] text-blood-400/80">downstream match #{conflict.payload.downstream_match_id}</span>}
            </span>
          </div>
        )}

        <div className="grid gap-2 sm:grid-cols-2" role="radiogroup" aria-label="Winner">
          {[top, bottom].map((c) =>
            c ? (
              <button
                key={c.id}
                type="button"
                role="radio"
                aria-checked={winnerId === c.id}
                onClick={() => setWinnerId(c.id)}
                className={cn(
                  'flex min-h-[44px] items-center gap-2 rounded-lg border px-3 py-1.5 text-left transition-all',
                  winnerId === c.id ? 'border-pin-500 bg-pin-500/15 text-pin-300' : 'border-mat-600 bg-mat-800 text-ink-300 hover:border-mat-500'
                )}
              >
                <span className="truncate text-sm font-semibold">#{c.seed} {c.name}</span>
              </button>
            ) : null
          )}
        </div>

        <div className="flex flex-wrap gap-1.5">
          {Object.entries(VICTORY_TYPES).map(([key, v]) => (
            <button
              key={key}
              type="button"
              title={v.name}
              onClick={() => setVictory(key)}
              className={cn(
                'min-h-[36px] rounded-lg border px-2.5 font-mono text-xs font-bold transition-colors',
                victory === key ? 'border-gold-500 bg-gold-500 text-mat-950' : 'border-mat-600 bg-mat-800 text-ink-400 hover:border-mat-500'
              )}
            >
              {v.label}
            </button>
          ))}
        </div>

        <Input label="Score" value={score} onChange={(e) => setScore(e.target.value)} placeholder="7-2" />
        <Textarea
          label="Change reason (required)"
          rows={2}
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="e.g. Scoreboard misreported the fall time"
        />

        <div className="flex justify-end gap-2">
          <Button variant="ghost" type="button" onClick={onClose} disabled={mut.isPending}>Cancel</Button>
          <Button variant="primary" type="submit" disabled={!winnerId || !reason.trim()} loading={mut.isPending}>
            <Check size={15} /> Apply correction
          </Button>
        </div>
      </form>
    </Modal>
  )
}

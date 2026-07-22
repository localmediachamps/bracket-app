import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import confetti from 'canvas-confetti'
import { AlertTriangle, ArrowLeft, Lock, PanelRightOpen, RotateCcw, Send, Timer } from 'lucide-react'
import { api } from '../lib/api'
import { toast } from '../lib/store'
import { cn } from '../lib/utils'
import { Button, Card, Countdown, EmptyState, Skeleton, StatusPill } from '../components/ui'
import BracketView from '../components/bracket/BracketView'
import usePredictPicks from '../components/predict/usePredictPicks'
import WeightRail from '../components/predict/WeightRail'
import ChampsDrawer from '../components/predict/ChampsDrawer'
import SubmitModal from '../components/predict/SubmitModal'
import SaveStateIndicator from '../components/predict/SaveStateIndicator'

const CLOSED_STATUSES = ['locked', 'live', 'completed']

/** Tournament overview may arrive flat or nested under `tournament`. */
function normalizeOverview(data) {
  if (!data) return null
  const base = data.tournament && typeof data.tournament === 'object' ? { ...data.tournament } : { ...data }
  return {
    ...base,
    weight_classes: data.weight_classes ?? base.weight_classes ?? [],
    my_entry: data.my_entry ?? data.entry ?? null,
    my_pickem_entry: data.my_pickem_entry ?? data.pickem_entry ?? null,
  }
}

function fireGoldConfetti() {
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return
  const colors = ['#E8AE2E', '#F5C44F', '#FFD87A', '#FFF3D6']
  confetti({ particleCount: 90, spread: 75, startVelocity: 42, origin: { y: 0.22 }, colors })
  setTimeout(() => confetti({ particleCount: 130, spread: 110, startVelocity: 38, origin: { y: 0.3 }, colors, scalar: 0.9 }), 240)
}

export default function Predict() {
  const { slug } = useParams()
  const queryClient = useQueryClient()

  /* ── tournament overview ─────────────────────────────────── */
  const tQuery = useQuery({ queryKey: ['tournament', slug], queryFn: () => api.tournament(slug) })
  const tournament = useMemo(() => normalizeOverview(tQuery.data), [tQuery.data])
  const weightClasses = useMemo(
    () =>
      [...(tournament?.weight_classes ?? [])].sort(
        (a, b) => (a.display_order ?? 0) - (b.display_order ?? 0) || (a.weight ?? 0) - (b.weight ?? 0)
      ),
    [tournament]
  )

  /* ── entry (get-or-create once) ──────────────────────────── */
  const [entry, setEntry] = useState(null)
  const createTriedRef = useRef(false)
  const createMut = useMutation({
    mutationFn: () => api.createEntry(tournament.id),
    onSuccess: (res) => {
      const ent = res?.entry ?? res
      setEntry(ent)
      queryClient.setQueryData(['tournament', slug], (old) => (old ? { ...old, my_entry: ent } : old))
    },
    onError: (err) => toast.error("Couldn't start your bracket", { body: err.message }),
  })

  /* ── picks model (global across weights) ─────────────────── */
  const {
    picks,
    progress,
    dirtyCount,
    reset,
    hasUnsaved,
    mergeWeight,
    mergePickList,
    applyPick,
    removeInvalid,
    applyServerCleared,
    markSaved,
    snapshot,
  } = usePredictPicks()

  /* ── ui state ────────────────────────────────────────────── */
  const [activeWeightId, setActiveWeightId] = useState(null)
  const [weightDataMap, setWeightDataMap] = useState({}) // wcId → bracketView response (loaded weights)
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [submitOpen, setSubmitOpen] = useState(false)
  const [missingCount, setMissingCount] = useState(null)
  const [saveState, setSaveState] = useState('saved')

  /* reset everything when navigating between tournaments */
  useEffect(() => {
    setEntry(null)
    setActiveWeightId(null)
    setWeightDataMap({})
    setDrawerOpen(false)
    setSubmitOpen(false)
    setMissingCount(null)
    setSaveState('saved')
    createTriedRef.current = false
    reset()
  }, [slug, reset])

  /* sync entry from the overview (first time only) */
  const overviewEntry = tournament?.my_entry
  useEffect(() => {
    if (overviewEntry) setEntry((prev) => prev ?? overviewEntry)
  }, [overviewEntry])

  /* create entry on mount when the tournament is open and none exists */
  useEffect(() => {
    if (!tournament || overviewEntry || tournament.status !== 'open') return
    if (createTriedRef.current) return
    createTriedRef.current = true
    createMut.mutate()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tournament, overviewEntry])

  /* default active weight = first weight class */
  useEffect(() => {
    if (activeWeightId == null && weightClasses.length) setActiveWeightId(weightClasses[0].id)
  }, [weightClasses, activeWeightId])

  /* ── entry detail: ALL picks (protects unloaded weights on full-replace save) ── */
  const entryQuery = useQuery({
    queryKey: ['entry', entry?.id],
    queryFn: () => api.entry(entry.id),
    enabled: !!entry?.id,
    staleTime: 30000,
  })
  useEffect(() => {
    const data = entryQuery.data
    if (!data) return
    mergePickList(data.picks ?? data.entry?.picks ?? [])
  }, [entryQuery.data, mergePickList])

  /* ── active weight bracket (cached per weight → instant switching) ── */
  const bracketQuery = useQuery({
    queryKey: ['bracket', tournament?.id, activeWeightId, entry?.id],
    queryFn: () => api.bracketView(tournament.id, activeWeightId, entry.id),
    enabled: !!tournament?.id && activeWeightId != null && !!entry?.id,
    staleTime: 30000,
  })
  const bracketData = bracketQuery.data

  useEffect(() => {
    if (!bracketData || activeWeightId == null) return
    mergeWeight(bracketData)
    setWeightDataMap((prev) => (prev[activeWeightId] === bracketData ? prev : { ...prev, [activeWeightId]: bracketData }))
    if (bracketData.entry) setEntry((prev) => (prev ? { ...prev, ...bracketData.entry } : prev))
  }, [bracketData, activeWeightId, mergeWeight])

  /* ── derived ─────────────────────────────────────────────── */
  const matches = useMemo(() => bracketData?.matches ?? [], [bracketData])
  const competitorsById = useMemo(
    () => new Map((bracketData?.competitors ?? []).map((c) => [c.id, c])),
    [bracketData]
  )
  const tournamentClosed = CLOSED_STATUSES.includes(tournament?.status)
  const readOnly = !!entry && (entry.status === 'locked' || tournamentClosed)

  /* weight-filtered picks for BracketView (its resolver validates per weight) */
  const weightPicks = useMemo(() => {
    const ids = new Set(matches.map((m) => m.id))
    const out = new Map()
    for (const [id, wid] of picks) if (ids.has(id)) out.set(id, wid)
    return out
  }, [picks, matches])

  const railStats = useMemo(() => {
    const map = new Map()
    for (const [wcId, data] of Object.entries(weightDataMap)) {
      const list = (data.matches ?? []).filter((m) => !m.is_bye)
      let picked = 0
      for (const m of list) if (picks.has(m.id)) picked++
      map.set(Number(wcId), { picked, total: list.length })
    }
    return map
  }, [weightDataMap, picks])

  const champions = useMemo(
    () =>
      weightClasses.map((wc) => {
        const data = weightDataMap[wc.id]
        const finals = data?.matches?.find((m) => m.round_code === 'champ_finals')
        const pickId = finals ? picks.get(finals.id) : null
        const comp = pickId ? (data.competitors ?? []).find((c) => c.id === pickId) : null
        return { wc, loaded: !!data, comp: comp ?? null }
      }),
    [weightClasses, weightDataMap, picks]
  )

  const unresolved = useMemo(() => {
    const out = []
    for (const wc of weightClasses) {
      const data = weightDataMap[wc.id]
      if (!data) continue
      for (const m of data.matches ?? []) {
        if (m.is_bye) continue
        if (m.status === 'complete' || m.status === 'corrected') continue
        if (picks.has(m.id)) continue
        out.push({ weightId: wc.id, weightLabel: wc.weight ?? wc.name, match: m })
      }
    }
    return out
  }, [weightClasses, weightDataMap, picks])

  /* ── autosave (debounced 900ms, full-replace payload) ────── */
  const saveTimer = useRef(null)
  const retryTimer = useRef(null)
  const inFlight = useRef(false)
  const doSaveRef = useRef(null)

  const doSave = useCallback(
    async (attempt = 0) => {
      const entryId = entry?.id
      if (!entryId || inFlight.current) return
      inFlight.current = true
      const snap = snapshot()
      setSaveState(attempt > 0 ? 'retrying' : 'saving')
      try {
        const payload = [...snap].map(([bracket_match_id, wrestler_id]) => ({ bracket_match_id, wrestler_id }))
        const res = await api.savePicks(entryId, payload)
        // No toast here — cascading clears are already visible in the
        // bracket itself, and the user is typically clicking through picks
        // quickly enough that a toast per save would just be noise.
        if (res?.cleared?.length) applyServerCleared(res.cleared)
        markSaved(snap, res?.progress)
        setSaveState('saved')
      } catch (err) {
        if (attempt === 0) {
          setSaveState('retrying')
          retryTimer.current = setTimeout(() => doSaveRef.current?.(1), 1600)
        } else {
          // No toast here either — the "Save failed" status pill already
          // surfaces this, and a failing autosave retries on every
          // subsequent pick, which would otherwise stack up duplicate toasts.
          setSaveState('error')
        }
      } finally {
        inFlight.current = false
        if (hasUnsaved()) scheduleSave(500)
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [entry?.id, snapshot, applyServerCleared, markSaved, hasUnsaved]
  )

  const scheduleSave = useCallback((delay = 900) => {
    clearTimeout(saveTimer.current)
    saveTimer.current = setTimeout(() => doSaveRef.current?.(0), delay)
  }, [])

  useEffect(() => {
    doSaveRef.current = doSave
  }, [doSave])

  useEffect(() => {
    if (dirtyCount === 0 || readOnly || !entry?.id) return
    scheduleSave(900)
    return () => clearTimeout(saveTimer.current)
  }, [dirtyCount, readOnly, entry?.id, scheduleSave])

  useEffect(
    () => () => {
      clearTimeout(saveTimer.current)
      clearTimeout(retryTimer.current)
    },
    []
  )

  /* ── pick handlers ───────────────────────────────────────── */
  const handlePick = useCallback(
    (match, wrestlerId) => {
      // No toast on cascading clears — visible directly in the bracket as
      // downstream matches revert to TBD, and toasting on every pick during
      // a fast run through the bracket is more noise than signal.
      applyPick(match, wrestlerId, matches, competitorsById)
    },
    [applyPick, matches, competitorsById]
  )

  const handlePicksCleared = useCallback((ids) => removeInvalid(ids), [removeInvalid])

  /* ── drawer jump → switch weight + scroll match into view ── */
  const jumpToMatch = useCallback(
    (weightId, matchId) => {
      setDrawerOpen(false)
      const go = () => {
        const el = document.querySelector(`[data-match-id="${matchId}"]`)
        if (!el) return
        el.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'center' })
        el.classList.add('predict-flash')
        window.setTimeout(() => el.classList.remove('predict-flash'), 2000)
      }
      if (weightId !== activeWeightId) {
        setActiveWeightId(weightId)
        window.setTimeout(go, 420)
      } else {
        window.setTimeout(go, 80)
      }
    },
    [activeWeightId]
  )

  /* ── submit ──────────────────────────────────────────────── */
  const submitMut = useMutation({
    mutationFn: () => api.submitEntry(entry.id),
    onSuccess: (res) => {
      const e = res?.entry ?? res
      setEntry((prev) => ({ ...prev, ...(e?.id ? e : {}), status: e?.status ?? 'submitted' }))
      queryClient.setQueryData(['tournament', slug], (old) =>
        old ? { ...old, my_entry: { ...(old.my_entry ?? {}), status: 'submitted' } } : old
      )
      setSubmitOpen(false)
      fireGoldConfetti()
      toast.success('Bracket submitted!', { body: 'You can keep editing until the deadline.' })
    },
    onError: (err) => {
      const missing = err?.payload?.missing
      if (missing?.length || /incomplete/i.test(err?.message ?? '')) {
        setMissingCount(missing?.length ?? null)
        toast.error('Bracket incomplete', {
          body: missing?.length ? `${missing.length} matches still need picks.` : err.message,
        })
      } else {
        toast.error('Submit failed', { body: err.message })
      }
    },
  })

  const openSubmit = useCallback(() => {
    setMissingCount(null)
    setSubmitOpen(true)
    if (hasUnsaved()) {
      clearTimeout(saveTimer.current)
      doSaveRef.current?.(0) // flush so server-side completeness check sees fresh picks
    }
  }, [hasUnsaved])

  /* ── render gates ────────────────────────────────────────── */
  if (tQuery.isLoading) return <PageSkeleton />
  if (tQuery.isError) {
    return <ErrorState title="Couldn't load this tournament" body={tQuery.error?.message} onRetry={() => tQuery.refetch()} />
  }
  if (!tournament) return null

  if (tournament.status === 'cancelled') {
    return (
      <EmptyState
        icon={<Lock size={26} />}
        title="Tournament cancelled"
        body="This tournament was cancelled by the organizers."
        action={<Link to={`/tournaments/${slug}`}><Button variant="secondary">Back to tournament</Button></Link>}
      />
    )
  }

  if (!entry) {
    if (tournament.status !== 'open') {
      return (
        <EmptyState
          icon={<Lock size={26} />}
          title="Predictions are closed"
          body="The deadline to enter this tournament has passed. You can still follow the bracket and leaderboard."
          action={<Link to={`/tournaments/${slug}`}><Button variant="secondary">Go to tournament hub</Button></Link>}
        />
      )
    }
    if (createMut.isError) {
      return (
        <ErrorState
          title="Couldn't start your bracket"
          body={createMut.error?.message}
          onRetry={() => createMut.mutate()}
        />
      )
    }
    return (
      <div className="flex flex-col items-center gap-3 py-24">
        <Skeleton className="h-8 w-72" />
        <Skeleton className="h-4 w-48" />
        <p className="mt-2 text-sm font-semibold text-ink-500">Setting up your bracket…</p>
      </div>
    )
  }

  const pct = progress.total > 0 ? Math.min(100, (progress.picked / progress.total) * 100) : 0
  const remaining = Math.max(0, progress.total - progress.picked)
  const submitTitle = readOnly
    ? 'Picks are locked'
    : progress.complete
      ? 'Submit your bracket'
      : progress.total > 0
        ? `${remaining} ${remaining === 1 ? 'match' : 'matches'} left to pick`
        : 'Loading bracket…'

  return (
    <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18 }} className="space-y-4">
      {/* flash highlight for drawer jumps (canvas mode has no native scroll target) */}
      <style>{`.predict-flash{outline:2px solid var(--color-gold-400);outline-offset:2px;box-shadow:0 0 26px -4px rgb(232 174 46 / 0.6);border-radius:8px;}`}</style>

      {/* ── header ── */}
      <header className="space-y-3">
        <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
          <Link
            to={`/tournaments/${slug}`}
            className="flex items-center gap-1 text-xs font-bold uppercase tracking-wider text-ink-500 transition-colors hover:text-gold-400"
          >
            <ArrowLeft size={14} /> Hub
          </Link>
          <h1 className="min-w-0 truncate font-display text-lg uppercase tracking-tight text-ink-100">{tournament.name}</h1>
          <StatusPill status={tournament.status} />
          <StatusPill status={entry.status} />
          <div className="ml-auto flex flex-wrap items-center gap-x-4 gap-y-2">
            {tournament.locks_at > 0 && (
              <span className="flex items-center gap-1.5 text-xs font-semibold text-ink-500">
                <Timer size={13} className="text-gold-500" />
                <Countdown to={tournament.locks_at} />
              </span>
            )}
            {!readOnly && <SaveStateIndicator state={saveState} onRetry={() => doSaveRef.current?.(0)} />}
            <Button variant="secondary" size="sm" onClick={() => setDrawerOpen(true)}>
              <PanelRightOpen size={15} /> My Champs
            </Button>
            {!readOnly && (
              <Button size="sm" disabled={!progress.complete} title={submitTitle} onClick={openSubmit}>
                <Send size={14} /> {entry.status === 'submitted' ? 'Resubmit' : 'Submit'}
              </Button>
            )}
          </div>
        </div>
        <div className="flex items-center gap-3">
          <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-mat-700" role="progressbar" aria-valuenow={progress.picked} aria-valuemax={progress.total} aria-label="Picks completed">
            <motion.div
              className={cn('h-full rounded-full', progress.complete ? 'bg-pin-500' : 'bg-gold-500')}
              initial={{ width: 0 }}
              animate={{ width: `${pct}%` }}
              transition={{ type: 'spring', damping: 26, stiffness: 200 }}
            />
          </div>
          <span className="font-mono text-xs font-bold text-ink-400">
            {progress.picked}
            <span className="text-ink-600">/{progress.total || '—'}</span>
          </span>
        </div>
      </header>

      {/* ── locked banner ── */}
      {readOnly && (
        <Card className="flex flex-wrap items-center gap-3 border-gold-500/40 bg-gold-500/5 p-4">
          <Lock size={16} className="shrink-0 text-gold-400" />
          <div className="min-w-0 flex-1">
            <p className="text-sm font-bold text-ink-100">Picks are locked</p>
            <p className="text-xs text-ink-500">This bracket is no longer editable — track how your picks are scoring.</p>
          </div>
          <Link to={`/entries/${entry.id}/review`}>
            <Button variant="secondary" size="sm">
              Review entry
            </Button>
          </Link>
        </Card>
      )}

      {/* ── weight rail ── */}
      <WeightRail weightClasses={weightClasses} activeId={activeWeightId} onSelect={setActiveWeightId} stats={railStats} />

      {/* ── bracket ── */}
      {bracketQuery.isLoading ? (
        <BracketSkeleton />
      ) : bracketQuery.isError ? (
        <ErrorState
          title="Couldn't load this bracket"
          body={bracketQuery.error?.message}
          onRetry={() => bracketQuery.refetch()}
        />
      ) : (
        <BracketView
          data={bracketData}
          mode={readOnly ? 'results' : 'predict'}
          picks={readOnly ? undefined : weightPicks}
          onPick={readOnly ? undefined : handlePick}
          onPicksCleared={readOnly ? undefined : handlePicksCleared}
        />
      )}

      {/* ── summary drawer / sheet ── */}
      <ChampsDrawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        champions={champions}
        unresolved={unresolved}
        railStats={railStats}
        progress={progress}
        onJump={jumpToMatch}
      />

      {/* ── submit confirm ── */}
      <SubmitModal
        open={submitOpen}
        onClose={() => setSubmitOpen(false)}
        champions={champions}
        onConfirm={() => submitMut.mutate()}
        submitting={submitMut.isPending}
        missingCount={missingCount}
        locksAt={tournament.locks_at}
      />
    </motion.div>
  )
}

/* ── states ─────────────────────────────────────────────── */
function PageSkeleton() {
  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <Skeleton className="h-6 w-16" />
        <Skeleton className="h-7 w-64" />
        <Skeleton className="ml-auto h-8 w-40" />
      </div>
      <Skeleton className="h-1.5 w-full" />
      <div className="flex gap-2">
        {[...Array(6)].map((_, i) => (
          <Skeleton key={i} className="h-8 w-20 rounded-full" />
        ))}
      </div>
      <BracketSkeleton />
    </div>
  )
}

function BracketSkeleton() {
  return (
    <div className="overflow-hidden rounded-xl border border-mat-700 bg-mat-900/60 p-6">
      <div className="flex gap-14">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="flex shrink-0 flex-col gap-4">
            <Skeleton className="h-4 w-24" />
            {[...Array(Math.max(1, 5 - i))].map((_, j) => (
              <Skeleton key={j} className="h-[78px] w-[236px]" />
            ))}
          </div>
        ))}
      </div>
    </div>
  )
}

function ErrorState({ title, body, onRetry }) {
  return (
    <Card className="flex flex-col items-center gap-3 p-10 text-center">
      <AlertTriangle className="text-blood-400" size={22} />
      <p className="font-display text-sm uppercase tracking-wide text-ink-100">{title}</p>
      {body && <p className="max-w-md text-sm text-ink-500">{body}</p>}
      <Button variant="secondary" size="sm" onClick={onRetry}>
        <RotateCcw size={14} /> Try again
      </Button>
    </Card>
  )
}

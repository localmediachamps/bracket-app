import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQueries, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import confetti from 'canvas-confetti'
import { AlertTriangle, ArrowLeft, Globe, Lock, RotateCcw, Send, Sparkles, Timer } from 'lucide-react'
import { api } from '../lib/api'
import { toast } from '../lib/store'
import { Button, Card, Countdown, EmptyState, Input, Skeleton, StatusPill } from '../components/ui'
import BudgetMeter from '../components/pickem/BudgetMeter'
import WeightRow from '../components/pickem/WeightRow'
import WrestlerPicker from '../components/pickem/WrestlerPicker'
import SeedCostLegend from '../components/pickem/SeedCostLegend'
import ScoringExplainer from '../components/pickem/ScoringExplainer'
import PickemSubmitModal from '../components/pickem/PickemSubmitModal'
import SaveStateIndicator from '../components/pickem/SaveStateIndicator'
import BestScenarioCard from '../components/pickem/BestScenarioCard'
import { projectWrestlerPoints, solveBestScenario } from '../components/pickem/recommender'

const CLOSED_STATUSES = ['locked', 'live', 'completed']

const DEFAULT_CONFIG = {
  budget: 1000,
  seed_costs: { 1: 200, 2: 160, 3: 140, 4: 120, 5: 100, 6: 90, 7: 80, 8: 70, 9: 60, 10: 50, 11: 40, 12: 30, 13: 20, 14: 20, 15: 20, 16: 20, default: 10 },
  tiebreakers: [
    { key: 'tiebreaker_1', label: 'Tiebreaker 1', hint: '' },
    { key: 'tiebreaker_2', label: 'Tiebreaker 2', hint: '' },
    { key: 'tiebreaker_3', label: 'Tiebreaker 3', hint: '' },
  ],
  scoring: {
    placement_points: { 1: 16, 2: 12, 3: 10, 4: 9, 5: 8, 6: 7, 7: 6, 8: 5 },
    win_points: { championship: 1, consolation: 0.5 },
    bonus_points: { fall: 2, tech_fall: 1.5, major: 1 },
  },
}

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

function normalizeConfig(raw) {
  const cfg = raw && typeof raw === 'object' ? raw : {}
  const tiebreakers = (Array.isArray(cfg.tiebreakers) && cfg.tiebreakers.length ? cfg.tiebreakers : DEFAULT_CONFIG.tiebreakers).map(
    (t, i) => (typeof t === 'string' ? { key: t, label: t.replace(/_/g, ' '), hint: '' } : { key: t.key ?? `tiebreaker_${i + 1}`, label: t.label ?? `Tiebreaker ${i + 1}`, hint: t.hint ?? '' })
  )
  return {
    budget: cfg.budget ?? DEFAULT_CONFIG.budget,
    seed_costs: cfg.seed_costs ?? DEFAULT_CONFIG.seed_costs,
    tiebreakers,
    scoring: cfg.scoring ?? DEFAULT_CONFIG.scoring,
  }
}

function fireGoldConfetti() {
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return
  const colors = ['#E8AE2E', '#F5C44F', '#FFD87A', '#FFF3D6']
  confetti({ particleCount: 90, spread: 75, startVelocity: 42, origin: { y: 0.22 }, colors })
  setTimeout(() => confetti({ particleCount: 130, spread: 110, startVelocity: 38, origin: { y: 0.3 }, colors, scalar: 0.9 }), 240)
}

export default function Pickem() {
  const { slug } = useParams()
  const queryClient = useQueryClient()

  /* ── tournament overview ─────────────────────────────────── */
  const tQuery = useQuery({ queryKey: ['tournament', slug], queryFn: () => api.tournament(slug) })
  const tournament = useMemo(() => normalizeOverview(tQuery.data), [tQuery.data])
  const config = useMemo(() => normalizeConfig(tournament?.pickem_config), [tournament])
  const weightClasses = useMemo(
    () =>
      [...(tournament?.weight_classes ?? [])].sort(
        (a, b) => (a.display_order ?? 0) - (b.display_order ?? 0) || (a.weight ?? 0) - (b.weight ?? 0)
      ),
    [tournament]
  )
  const pickemEnabled = !Array.isArray(tournament?.game_modes) || tournament.game_modes.includes('pickem')

  /* ── entry (get-or-create once) ──────────────────────────── */
  const [entry, setEntry] = useState(null)
  const createTriedRef = useRef(false)
  const createMut = useMutation({
    mutationFn: () => api.createPickemEntry(tournament.id),
    onSuccess: (res) => {
      const ent = res?.entry ?? res
      setEntry(ent)
      queryClient.setQueryData(['tournament', slug], (old) => (old ? { ...old, my_pickem_entry: ent } : old))
    },
    onError: (err) => toast.error("Couldn't start your Pick'em entry", { body: err.message }),
  })

  /* ── picks + tiebreakers state ───────────────────────────── */
  const [picks, setPicks] = useState({}) // weightClassId → wrestlerId
  const [tiebreakers, setTiebreakers] = useState({}) // key → string
  const picksRef = useRef(picks)
  const tbRef = useRef(tiebreakers)
  const hydratedRef = useRef(false)
  const [unsaved, setUnsaved] = useState(false)
  const unsavedRef = useRef(false)
  const [saveState, setSaveState] = useState('saved')

  /* ui state */
  const [pickerWc, setPickerWc] = useState(null)
  const [submitOpen, setSubmitOpen] = useState(false)
  const [missingCount, setMissingCount] = useState(null)

  /* reset on tournament switch */
  useEffect(() => {
    setEntry(null)
    setPicks({})
    picksRef.current = {}
    setTiebreakers({})
    tbRef.current = {}
    hydratedRef.current = false
    setUnsaved(false)
    unsavedRef.current = false
    setSaveState('saved')
    setPickerWc(null)
    setSubmitOpen(false)
    setMissingCount(null)
    createTriedRef.current = false
  }, [slug])

  const overviewEntry = tournament?.my_pickem_entry
  useEffect(() => {
    if (overviewEntry) setEntry((prev) => prev ?? overviewEntry)
  }, [overviewEntry])

  useEffect(() => {
    if (!tournament || overviewEntry || tournament.status !== 'open' || !pickemEnabled) return
    if (createTriedRef.current) return
    createTriedRef.current = true
    createMut.mutate()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tournament, overviewEntry, pickemEnabled])

  /* ── entry detail (picks + per-pick breakdown) ───────────── */
  const entryQuery = useQuery({
    queryKey: ['pickem-entry', entry?.id],
    queryFn: () => api.pickemEntry(entry.id),
    enabled: !!entry?.id,
    staleTime: 30000,
  })
  const entryDetail = entryQuery.data
  const detailEntry = entryDetail?.entry ?? entryDetail
  const detailPicks = useMemo(() => entryDetail?.picks ?? [], [entryDetail])

  const visibilityMutation = useMutation({
    mutationFn: (isPublic) => api.setPickemEntryVisibility(entry.id, isPublic),
    onSuccess: (_data, isPublic) => {
      toast.success(isPublic ? 'Your picks are now public' : 'Your picks are now private')
      queryClient.invalidateQueries({ queryKey: ['pickem-entry', entry?.id] })
    },
    onError: (err) => toast.error('Could not update visibility', { body: err.message }),
  })

  useEffect(() => {
    if (!entryDetail || hydratedRef.current) return
    hydratedRef.current = true
    const p = {}
    for (const pick of detailPicks) if (pick.wrestler_id != null) p[pick.weight_class_id] = pick.wrestler_id
    setPicks(p)
    picksRef.current = p
    const tb = {}
    for (const t of config.tiebreakers) {
      const v = detailEntry?.[t.key]
      tb[t.key] = v == null ? '' : String(v)
    }
    setTiebreakers(tb)
    tbRef.current = tb
    if (detailEntry?.id) setEntry((prev) => ({ ...prev, ...detailEntry }))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [entryDetail])

  /* ── competitors per weight (cached; feeds rows + picker) ── */
  const weightQueries = useQueries({
    queries: weightClasses.map((wc) => ({
      queryKey: ['bracket-public', tournament?.id, wc.id],
      queryFn: () => api.bracketView(tournament.id, wc.id),
      enabled: !!tournament?.id && !!entry?.id,
      staleTime: 60000,
    })),
  })
  /* computed every render — cheap loops (≤ ~10 weights × ~33 competitors) */
  const competitorsMap = new Map()
  weightClasses.forEach((wc, i) => {
    const d = weightQueries[i]?.data
    if (d?.competitors) competitorsMap.set(wc.id, d.competitors)
  })
  const wrestlerById = new Map()
  for (const comps of competitorsMap.values()) for (const c of comps) wrestlerById.set(c.id, c)

  /* ── budget math ─────────────────────────────────────────── */
  const costOf = useCallback((wrestler) => config.seed_costs?.[String(wrestler?.seed)] ?? config.seed_costs?.default ?? 0, [config])
  const used = Object.values(picks).reduce((sum, wid) => sum + costOf(wrestlerById.get(wid)), 0)
  const over = used > config.budget
  const overRef = useRef(false)
  useEffect(() => {
    overRef.current = over
  }, [over])

  /* ── derived ─────────────────────────────────────────────── */
  const tournamentClosed = CLOSED_STATUSES.includes(tournament?.status)
  const readOnly = !!entry && (entry.status === 'locked' || tournamentClosed)
  const selections = Object.keys(picks).length
  const allPicked = weightClasses.length > 0 && weightClasses.every((wc) => picks[wc.id] != null)
  const pointsByWc = useMemo(() => new Map(detailPicks.map((p) => [p.weight_class_id, p])), [detailPicks])

  /* ── mutations ───────────────────────────────────────────── */
  const markDirty = useCallback(() => {
    unsavedRef.current = true
    setUnsaved(true)
  }, [])

  /* ── best-scenario recommender ───────────────────────────── */
  // Needs the user's OWN championship-bracket predictions (a separate entry
  // from this pick'em one) to project fantasy points per wrestler.
  const myBracketEntryQuery = useQuery({
    queryKey: ['tournament-my-entry', tournament?.id],
    queryFn: () => api.myEntry(tournament.id),
    enabled: !!tournament?.id,
    staleTime: 10000,
  })
  const bracketEntryId = myBracketEntryQuery.data?.id ?? null
  const bracketDetailQuery = useQuery({
    queryKey: ['entry', bracketEntryId],
    queryFn: () => api.entry(bracketEntryId),
    enabled: !!bracketEntryId,
    staleTime: 10000,
  })
  const bracketPicksMap = useMemo(() => {
    const m = new Map()
    for (const p of bracketDetailQuery.data?.picks ?? []) {
      if (p.bracket_match_id != null && p.wrestler_id != null) m.set(p.bracket_match_id, p.wrestler_id)
    }
    return m
  }, [bracketDetailQuery.data])

  const weightsLoaded = weightClasses.length > 0 && weightQueries.every((q) => q.data)
  const bestScenario = useMemo(() => {
    if (!weightsLoaded || bracketPicksMap.size === 0) return null
    const groups = weightClasses.map((wc, i) => {
      const data = weightQueries[i]?.data
      const matches = data?.matches ?? []
      const comps = data?.competitors ?? []
      const compById = new Map(comps.map((c) => [c.id, c]))
      const projections = projectWrestlerPoints(matches, bracketPicksMap, compById, config.scoring)
      return {
        key: wc.id,
        options: comps.map((c) => ({ id: c.id, cost: costOf(c), points: projections.get(c.id)?.points ?? 0 })),
      }
    })
    const solved = solveBestScenario(groups, config.budget)
    return { ...solved, groups }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [weightsLoaded, bracketPicksMap, weightClasses, config.scoring, config.budget])

  const applyBestScenario = useCallback(() => {
    if (!bestScenario?.selections?.size) return
    const next = {}
    for (const [wcId, wrestlerId] of bestScenario.selections) {
      if (wrestlerId != null) next[wcId] = wrestlerId
    }
    setPicks(next)
    picksRef.current = next
    markDirty()
    toast.success('Best Scenario applied', { body: 'Your roster is filled in — feel free to tweak it before submitting.' })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bestScenario, markDirty])

  const selectWrestler = useCallback(
    (wcId, wrestler) => {
      setPicks((prev) => {
        const next = { ...prev, [wcId]: wrestler.id }
        picksRef.current = next
        return next
      })
      markDirty()
      setPickerWc(null)
    },
    [markDirty]
  )

  const removePick = useCallback(
    (wcId) => {
      setPicks((prev) => {
        const next = { ...prev }
        delete next[wcId]
        picksRef.current = next
        return next
      })
      markDirty()
    },
    [markDirty]
  )

  const setTb = useCallback(
    (key, value) => {
      setTiebreakers((prev) => {
        const next = { ...prev, [key]: value }
        tbRef.current = next
        return next
      })
      markDirty()
    },
    [markDirty]
  )

  /* ── autosave (debounced 900ms; blocked while over budget) ─ */
  const saveTimer = useRef(null)
  const retryTimer = useRef(null)
  const inFlight = useRef(false)
  const doSaveRef = useRef(null)

  const doSave = useCallback(
    async (attempt = 0) => {
      const entryId = entry?.id
      if (!entryId || inFlight.current) return
      if (overRef.current) {
        setSaveState('blocked')
        return
      }
      inFlight.current = true
      setSaveState(attempt > 0 ? 'retrying' : 'saving')
      const payload = {
        picks: Object.entries(picksRef.current).map(([wcId, wid]) => ({ weight_class_id: Number(wcId), wrestler_id: wid })),
      }
      for (const t of config.tiebreakers) {
        const v = tbRef.current[t.key]
        payload[t.key] = v === '' || v == null ? null : Number(v)
      }
      try {
        await api.savePickem(entryId, payload)
        unsavedRef.current = false
        setUnsaved(false)
        setSaveState('saved')
      } catch (err) {
        if (attempt === 0) {
          setSaveState('retrying')
          retryTimer.current = setTimeout(() => doSaveRef.current?.(1), 1600)
        } else {
          setSaveState('error')
          toast.error("Couldn't save your picks", { body: err.message })
        }
      } finally {
        inFlight.current = false
        if (unsavedRef.current && !overRef.current) scheduleSave(500)
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [entry?.id, config]
  )

  const scheduleSave = useCallback((delay = 900) => {
    clearTimeout(saveTimer.current)
    saveTimer.current = setTimeout(() => doSaveRef.current?.(0), delay)
  }, [])

  useEffect(() => {
    doSaveRef.current = doSave
  }, [doSave])

  useEffect(() => {
    if (!unsaved || !entry?.id || readOnly) return
    if (over) {
      setSaveState('blocked')
      return
    }
    scheduleSave(900)
    return () => clearTimeout(saveTimer.current)
  }, [unsaved, over, entry?.id, readOnly, scheduleSave])

  useEffect(
    () => () => {
      clearTimeout(saveTimer.current)
      clearTimeout(retryTimer.current)
    },
    []
  )

  /* ── submit ──────────────────────────────────────────────── */
  const submitMut = useMutation({
    mutationFn: () => api.submitPickem(entry.id),
    onSuccess: (res) => {
      const e = res?.entry ?? res
      setEntry((prev) => ({ ...prev, ...(e?.id ? e : {}), status: e?.status ?? 'submitted' }))
      queryClient.setQueryData(['tournament', slug], (old) =>
        old ? { ...old, my_pickem_entry: { ...(old.my_pickem_entry ?? {}), status: 'submitted' } } : old
      )
      setSubmitOpen(false)
      fireGoldConfetti()
      toast.success("Pick'em submitted!", { body: 'You can keep editing until the deadline.' })
    },
    onError: (err) => {
      const missing = err?.payload?.missing
      if (missing?.length || /incomplete/i.test(err?.message ?? '')) {
        setMissingCount(missing?.length ?? null)
        toast.error('Roster incomplete', {
          body: missing?.length ? `${missing.length} weight classes still need a wrestler.` : err.message,
        })
      } else {
        toast.error('Submit failed', { body: err.message })
      }
    },
  })

  const openSubmit = useCallback(() => {
    setMissingCount(null)
    setSubmitOpen(true)
    if (unsavedRef.current && !overRef.current) {
      clearTimeout(saveTimer.current)
      doSaveRef.current?.(0)
    }
  }, [])

  /* ── render gates ────────────────────────────────────────── */
  if (tQuery.isLoading) return <PageSkeleton />
  if (tQuery.isError) {
    return <ErrorState title="Couldn't load this tournament" body={tQuery.error?.message} onRetry={() => tQuery.refetch()} />
  }
  if (!tournament) return null

  if (!pickemEnabled) {
    return (
      <EmptyState
        icon={<Lock size={26} />}
        title="Pick'em isn't enabled"
        body="This tournament only offers the bracket challenge."
        action={<Link to={`/tournaments/${slug}`}><Button variant="secondary">Back to tournament</Button></Link>}
      />
    )
  }

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
          title="Pick'em is closed"
          body="The deadline to enter this tournament has passed. You can still follow the leaderboard."
          action={<Link to={`/tournaments/${slug}`}><Button variant="secondary">Go to tournament hub</Button></Link>}
        />
      )
    }
    if (createMut.isError) {
      return <ErrorState title="Couldn't start your entry" body={createMut.error?.message} onRetry={() => createMut.mutate()} />
    }
    return (
      <div className="flex flex-col items-center gap-3 py-24">
        <Skeleton className="h-8 w-72" />
        <Skeleton className="h-4 w-48" />
        <p className="mt-2 text-sm font-semibold text-ink-500">Setting up your roster…</p>
      </div>
    )
  }

  const canSubmit = allPicked && !over && !readOnly
  const submitTitle = readOnly
    ? 'Picks are locked'
    : over
      ? 'Over budget — remove cost first'
      : !allPicked
        ? 'Pick a wrestler for every weight class'
        : 'Submit your roster'
  const submitRows = weightClasses.map((wc) => ({ wc, wrestler: wrestlerById.get(picks[wc.id]) ?? null, cost: costOf(wrestlerById.get(picks[wc.id])) }))
  const pickerIndex = pickerWc ? weightClasses.findIndex((wc) => wc.id === pickerWc.id) : -1
  const pickerQuery = pickerIndex >= 0 ? weightQueries[pickerIndex] : null

  return (
    <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18 }} className="space-y-4">
      {/* ── header ── */}
      <header className="flex flex-wrap items-center gap-x-3 gap-y-2">
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
          {entry?.id && (entry.status === 'submitted' || entry.status === 'locked') && (
            <Button
              size="sm"
              variant="secondary"
              loading={visibilityMutation.isPending}
              onClick={() => visibilityMutation.mutate(!entry.is_public)}
              title={entry.is_public ? 'Anyone with the link can view your picks' : 'Only you can view your picks'}
            >
              {entry.is_public ? <Globe size={14} /> : <Lock size={14} />}
              {entry.is_public ? 'Public' : 'Private'}
            </Button>
          )}
          {!readOnly && (
            <Button size="sm" disabled={!canSubmit} title={submitTitle} onClick={openSubmit}>
              <Send size={14} /> {entry.status === 'submitted' ? 'Resubmit' : 'Submit'}
            </Button>
          )}
        </div>
      </header>

      {/* ── locked banner ── */}
      {readOnly && (
        <Card className="flex flex-wrap items-center gap-3 border-gold-500/40 bg-gold-500/5 p-4">
          <Lock size={16} className="shrink-0 text-gold-400" />
          <div className="min-w-0 flex-1">
            <p className="text-sm font-bold text-ink-100">Picks are locked</p>
            <p className="text-xs text-ink-500">This roster is no longer editable — watch your wrestlers score.</p>
          </div>
          {entry.total_points != null && (
            <span className="font-mono text-lg font-bold text-gold-400">{entry.total_points} pts</span>
          )}
        </Card>
      )}

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
        {/* ── main column ── */}
        <div className="space-y-3">
          <BudgetMeter used={used} budget={config.budget} over={over} selections={selections} totalWeights={weightClasses.length} />

          {weightClasses.length === 0 ? (
            <EmptyState
              icon={<AlertTriangle size={26} />}
              title="No weight classes yet"
              body="The organizer hasn't published weight classes for this tournament."
            />
          ) : (
            weightClasses.map((wc, i) => {
              const wid = picks[wc.id]
              const wrestler = wid != null ? wrestlerById.get(wid) : null
              const serverPick = pointsByWc.get(wc.id)
              return (
                <WeightRow
                  key={wc.id}
                  index={i}
                  wc={wc}
                  wrestler={wrestler}
                  cost={costOf(wrestler)}
                  loading={wid != null && !wrestler}
                  readOnly={readOnly}
                  pointsEarned={serverPick?.points_earned}
                  breakdown={serverPick?.breakdown}
                  onOpen={() => setPickerWc(wc)}
                  onRemove={() => removePick(wc.id)}
                />
              )
            })
          )}

          {/* ── tiebreakers ── */}
          {config.tiebreakers.length > 0 && (
            <Card className="space-y-4 p-4">
              <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">Tiebreakers</p>
              <div className="grid gap-4 sm:grid-cols-3">
                {config.tiebreakers.map((t) => (
                  <Input
                    key={t.key}
                    type="number"
                    step="any"
                    label={t.label}
                    hint={t.hint}
                    value={tiebreakers[t.key] ?? ''}
                    onChange={(e) => setTb(t.key, e.target.value)}
                    disabled={readOnly}
                    aria-label={t.label}
                  />
                ))}
              </div>
            </Card>
          )}
        </div>

        {/* ── sidebar ── */}
        <div className="space-y-4">
          {!readOnly && (
            <BestScenarioCard
              bestScenario={bestScenario}
              hasBracketPicks={bracketPicksMap.size > 0}
              budget={config.budget}
              onApply={applyBestScenario}
              disabled={!bestScenario?.selections?.size}
            />
          )}
          <SeedCostLegend seedCosts={config.seed_costs} />
          <ScoringExplainer scoring={config.scoring} />
        </div>
      </div>

      {/* ── picker modal ── */}
      <WrestlerPicker
        open={!!pickerWc}
        onClose={() => setPickerWc(null)}
        weightClass={pickerWc}
        competitors={pickerWc ? competitorsMap.get(pickerWc.id) : null}
        loading={!!pickerQuery?.isLoading}
        error={pickerQuery?.isError ? pickerQuery.error?.message ?? "Couldn't load competitors" : null}
        onRetry={() => pickerQuery?.refetch()}
        selectedId={pickerWc ? picks[pickerWc.id] : null}
        picks={picks}
        weightClasses={weightClasses}
        seedCosts={config.seed_costs}
        recommendedId={pickerWc ? bestScenario?.selections?.get(pickerWc.id) ?? null : null}
        onSelect={(w) => pickerWc && selectWrestler(pickerWc.id, w)}
      />

      {/* ── submit confirm ── */}
      <PickemSubmitModal
        open={submitOpen}
        onClose={() => setSubmitOpen(false)}
        rows={submitRows}
        used={used}
        budget={config.budget}
        tiebreakers={tiebreakers}
        tiebreakerConfig={config.tiebreakers}
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
      <Skeleton className="h-24 w-full" />
      {[...Array(5)].map((_, i) => (
        <Skeleton key={i} className="h-16 w-full" />
      ))}
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

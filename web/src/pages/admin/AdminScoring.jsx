import React, { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowDown, ArrowUp, RefreshCw, Save, TriangleAlert } from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Button, Card, Skeleton, Tabs } from '../../components/ui'
import { ConfirmModal, ErrorState, PageHeader } from '../../components/admin/AdminCommon'
import {
  errMsg, normalizePickemConfig, normalizeScoringConfig, TIEBREAKER_LABELS,
} from '../../components/admin/adminUtils'

export default function AdminScoring() {
  const { id } = useParams()
  const qc = useQueryClient()
  const [tab, setTab] = useState('bracket')

  const tQ = useQuery({ queryKey: ['admin', 'tournament', id], queryFn: () => api.tournament(id) })
  const tournament = tQ.data?.tournament ?? tQ.data

  const sQ = useQuery({ queryKey: ['admin', 'scoring-config', id], queryFn: () => api.adminGetScoringConfig(id) })
  const pQ = useQuery({ queryKey: ['admin', 'pickem-config', id], queryFn: () => api.adminGetPickemConfig(id), retry: 1 })

  const [scoring, setScoring] = useState(null)
  const [pickem, setPickem] = useState(null)
  useEffect(() => {
    if (sQ.data) setScoring(normalizeScoringConfig(sQ.data))
  }, [sQ.data])
  useEffect(() => {
    if (pQ.data) setPickem(normalizePickemConfig(pQ.data))
    else if (pQ.isError) setPickem(normalizePickemConfig(null))
  }, [pQ.data, pQ.isError])

  /* results likely exist → warn before bumping scoring version */
  const resultsLikely = ['live', 'completed', 'archived'].includes(tournament?.status) || (scoring?.version ?? 1) > 1
  const [warnSave, setWarnSave] = useState(null) // 'bracket' | 'pickem'
  const [offerRescore, setOfferRescore] = useState(false)

  const saveScoringMut = useMutation({
    mutationFn: () => api.adminSaveScoringConfig(id, scoring),
    onSuccess: (res) => {
      toast.success('Scoring config saved', { body: `Version ${res?.version ?? (scoring.version ?? 1) + (resultsLikely ? 1 : 0)}` })
      setOfferRescore(true)
      qc.invalidateQueries({ queryKey: ['admin', 'scoring-config', id] })
    },
    onError: (e) => toast.error('Save failed', { body: errMsg(e) }),
  })

  const savePickemMut = useMutation({
    mutationFn: () => api.adminSavePickemConfig(id, pickem),
    onSuccess: () => {
      toast.success("Pick'em config saved")
      setOfferRescore(true)
      qc.invalidateQueries({ queryKey: ['admin', 'pickem-config', id] })
    },
    onError: (e) => toast.error('Save failed', { body: errMsg(e) }),
  })

  const rescoreMut = useMutation({
    mutationFn: () => api.adminRescore(id),
    onSuccess: (res) => {
      const summary = res?.entries_scored ?? res?.entries ?? res?.rescored
      toast.success('Full rescore complete', { body: summary != null ? `${summary} entries rescored and re-ranked.` : 'All entries rescored and re-ranked.' })
      setOfferRescore(false)
    },
    onError: (e) => toast.error('Rescore failed', { body: errMsg(e) }),
  })

  const requestSave = (which) => {
    if (resultsLikely) setWarnSave(which)
    else if (which === 'bracket') saveScoringMut.mutate()
    else savePickemMut.mutate()
  }

  if (sQ.isLoading || tQ.isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-9 w-72" />
        <Skeleton className="h-40" />
        <Skeleton className="h-40" />
      </div>
    )
  }
  if (sQ.isError) return <ErrorState error={sQ.error} onRetry={() => sQ.refetch()} title="Couldn't load scoring config" />
  if (!scoring) return null

  return (
    <div>
      <PageHeader
        title="Scoring"
        sub={`${tournament?.name ?? ''} · bracket points, pick'em, tiebreakers`}
        actions={
          offerRescore ? (
            <Button variant="secondary" size="sm" onClick={() => rescoreMut.mutate()} loading={rescoreMut.isPending}>
              <RefreshCw size={14} /> Run full rescore now
            </Button>
          ) : undefined
        }
      />

      {resultsLikely && (
        <Card className="mb-5 flex items-start gap-3 border-gold-500/40 bg-gold-500/5 p-4">
          <TriangleAlert size={16} className="mt-0.5 shrink-0 text-gold-400" />
          <p className="text-sm text-ink-300">
            This tournament may already have scored results. Saving bumps the <strong className="text-gold-300">scoring version</strong> (currently v{scoring.version ?? 1}) and is audited — run a rescore afterwards to apply it to existing entries.
          </p>
        </Card>
      )}

      <Tabs
        className="mb-5"
        active={tab}
        onChange={setTab}
        tabs={[
          { key: 'bracket', label: 'Bracket Challenge' },
          { key: 'pickem', label: "Pick'em" },
        ]}
      />

      {tab === 'bracket' ? (
        <BracketScoringEditor scoring={scoring} setScoring={setScoring} />
      ) : pickem ? (
        <PickemEditor pickem={pickem} setPickem={setPickem} />
      ) : (
        <Skeleton className="h-64" />
      )}

      <div className="mt-6 flex items-center justify-end gap-3">
        {offerRescore && <span className="text-xs text-ink-500">Saved — rescore applies the new config to existing entries.</span>}
        <Button
          variant="primary"
          onClick={() => requestSave(tab)}
          loading={saveScoringMut.isPending || savePickemMut.isPending}
        >
          <Save size={15} /> Save {tab === 'bracket' ? 'bracket scoring' : "pick'em config"}
        </Button>
      </div>

      <ConfirmModal
        open={!!warnSave}
        onClose={() => setWarnSave(null)}
        title="Bump scoring version?"
        body="Matches may already have results. Saving bumps the scoring version and is audited — existing entries keep their current totals until you run a rescore."
        confirmLabel="Save & bump version"
        loading={saveScoringMut.isPending || savePickemMut.isPending}
        onConfirm={() => {
          const which = warnSave
          setWarnSave(null)
          if (which === 'bracket') saveScoringMut.mutate()
          else savePickemMut.mutate()
        }}
      />
    </div>
  )
}

/* ── small number cell ──────────────────────────────── */
function NumCell({ label, value, onChange }) {
  return (
    <label className="block">
      <span className="mb-1 block text-[10px] font-bold uppercase tracking-wider text-ink-500">{label}</span>
      <input
        type="number"
        step="any"
        value={value}
        onChange={(e) => onChange(e.target.value === '' ? '' : Number(e.target.value))}
        className="h-10 w-full rounded-xl border border-mat-600 bg-mat-800 px-3 text-center font-mono text-sm font-bold text-ink-100 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
      />
    </label>
  )
}

/* ── bracket scoring grid editor ────────────────────── */
const VICTORY_TYPE_LABELS = {
  decision: 'Decision', major: 'Major decision', tech_fall: 'Tech fall', fall: 'Fall',
  medical_forfeit: 'Medical forfeit', injury_default: 'Injury default', forfeit: 'Forfeit', disqualification: 'Disqualification',
}

const MULTIPLIER_TIER_LABELS = {
  contender: 'Contender (seed 1-4)', all_american: 'All-American (seed 5-8)', blood_round: 'Blood Round (seed 9-12)',
}

function BracketScoringEditor({ scoring, setScoring }) {
  const setRound = (section, round, v) => setScoring((s) => ({ ...s, bracket: { ...s.bracket, [section]: { ...s.bracket[section], [round]: v } } }))
  const setPlace = (code, v) => setScoring((s) => ({ ...s, bracket: { ...s.bracket, placement: { ...s.bracket.placement, [code]: v } } }))
  const setB = (patch) => setScoring((s) => ({ ...s, bracket: { ...s.bracket, ...patch } }))
  const setVictoryPoints = (type, v) =>
    setScoring((s) => ({ ...s, bracket: { ...s.bracket, victory_bonus_points: { ...s.bracket.victory_bonus_points, [type]: v } } }))
  const setMultiplier = (tier, v) =>
    setScoring((s) => ({
      ...s,
      bracket: { ...s.bracket, opponent_multipliers: { ...s.bracket.opponent_multipliers, [tier]: { ...s.bracket.opponent_multipliers[tier], multiplier: v } } },
    }))

  const move = (i, dir) =>
    setScoring((s) => {
      const arr = [...s.tiebreakers]
      const j = i + dir
      if (j < 0 || j >= arr.length) return s
      ;[arr[i], arr[j]] = [arr[j], arr[i]]
      return { ...s, tiebreakers: arr }
    })

  return (
    <div className="space-y-5">
      <Card className="p-5">
        <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Championship rounds</h3>
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-6">
          {[1, 2, 3, 4, 5, 6].map((r) => (
            <NumCell key={r} label={`Round ${r}`} value={scoring.bracket.championship[r]} onChange={(v) => setRound('championship', r, v)} />
          ))}
        </div>
      </Card>

      <Card className="p-5">
        <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Consolation rounds</h3>
        <div className="grid grid-cols-4 gap-3 sm:grid-cols-8">
          {[1, 2, 3, 4, 5, 6, 7, 8].map((r) => (
            <NumCell key={r} label={`Cons ${r}`} value={scoring.bracket.consolation[r]} onChange={(v) => setRound('consolation', r, v)} />
          ))}
        </div>
      </Card>

      <Card className="p-5">
        <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Placement & extras</h3>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
          <NumCell label="3rd place" value={scoring.bracket.placement.place_3} onChange={(v) => setPlace('place_3', v)} />
          <NumCell label="5th place" value={scoring.bracket.placement.place_5} onChange={(v) => setPlace('place_5', v)} />
          <NumCell label="7th place" value={scoring.bracket.placement.place_7} onChange={(v) => setPlace('place_7', v)} />
          <NumCell label="Pigtail" value={scoring.bracket.pigtail} onChange={(v) => setB({ pigtail: v })} />
          <NumCell label="Champ bonus" value={scoring.bracket.champion_bonus} onChange={(v) => setB({ champion_bonus: v })} />
        </div>
      </Card>

      <Card className="p-5">
        <h3 className="mb-1 font-display text-sm uppercase tracking-wide text-ink-100">Victory-type points</h3>
        <p className="mb-4 text-xs text-ink-500">Flat points added on top of a correct pick's round points, by how the match was won.</p>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {Object.keys(VICTORY_TYPE_LABELS).map((type) => (
            <NumCell
              key={type}
              label={VICTORY_TYPE_LABELS[type]}
              value={scoring.bracket.victory_bonus_points[type]}
              onChange={(v) => setVictoryPoints(type, v)}
            />
          ))}
        </div>
      </Card>

      <Card className="p-5">
        <h3 className="mb-1 font-display text-sm uppercase tracking-wide text-ink-100">Opponent-quality multiplier</h3>
        <p className="mb-4 text-xs text-ink-500">
          Multiplies a correct pick's round points (not victory-type points or placement bonuses) when the beaten opponent's
          composite national rank falls in the tier below. No effect until national rankings data exists.
        </p>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          {Object.keys(MULTIPLIER_TIER_LABELS).map((tier) => (
            <NumCell
              key={tier}
              label={MULTIPLIER_TIER_LABELS[tier]}
              value={scoring.bracket.opponent_multipliers[tier].multiplier}
              onChange={(v) => setMultiplier(tier, v)}
            />
          ))}
        </div>
      </Card>

      <Card className="p-5">
        <h3 className="mb-1 font-display text-sm uppercase tracking-wide text-ink-100">Tiebreaker order</h3>
        <p className="mb-4 text-xs text-ink-500">Rankings sort by these, top first.</p>
        <ol className="space-y-1.5">
          {scoring.tiebreakers.map((key, i) => (
            <li key={key} className="flex items-center gap-3 rounded-lg border border-mat-700 bg-mat-800/60 px-3 py-2">
              <span className="font-mono text-xs font-bold text-gold-400">{i + 1}.</span>
              <span className="flex-1 text-sm font-semibold text-ink-200">{TIEBREAKER_LABELS[key] ?? key}</span>
              <button
                type="button"
                aria-label={`Move ${TIEBREAKER_LABELS[key] ?? key} up`}
                disabled={i === 0}
                onClick={() => move(i, -1)}
                className="rounded-md p-1.5 text-ink-500 transition-colors hover:bg-mat-700 hover:text-gold-400 disabled:opacity-30"
              >
                <ArrowUp size={14} />
              </button>
              <button
                type="button"
                aria-label={`Move ${TIEBREAKER_LABELS[key] ?? key} down`}
                disabled={i === scoring.tiebreakers.length - 1}
                onClick={() => move(i, 1)}
                className="rounded-md p-1.5 text-ink-500 transition-colors hover:bg-mat-700 hover:text-gold-400 disabled:opacity-30"
              >
                <ArrowDown size={14} />
              </button>
            </li>
          ))}
        </ol>
      </Card>
    </div>
  )
}

/* ── pick'em editor ─────────────────────────────────── */
function PickemEditor({ pickem, setPickem }) {
  const setScoring = (patch) => setPickem((p) => ({ ...p, scoring: { ...p.scoring, ...patch } }))
  return (
    <div className="space-y-5">
      <Card className="p-5">
        <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Budget</h3>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <NumCell label="Budget" value={pickem.budget} onChange={(v) => setPickem((p) => ({ ...p, budget: v }))} />
        </div>
      </Card>

      <Card className="p-5">
        <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Seed costs</h3>
        <div className="grid grid-cols-4 gap-2 sm:grid-cols-9">
          {[...Array(16)].map((_, i) => i + 1).map((s) => (
            <NumCell key={s} label={`#${s}`} value={pickem.seed_costs[s]} onChange={(v) => setPickem((p) => ({ ...p, seed_costs: { ...p.seed_costs, [s]: v } }))} />
          ))}
          <NumCell label="Default" value={pickem.seed_costs.default} onChange={(v) => setPickem((p) => ({ ...p, seed_costs: { ...p.seed_costs, default: v } }))} />
        </div>
      </Card>

      <Card className="p-5">
        <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Placement points</h3>
        <div className="grid grid-cols-4 gap-2 sm:grid-cols-8">
          {[1, 2, 3, 4, 5, 6, 7, 8].map((p) => (
            <NumCell
              key={p}
              label={`${p}${p === 1 ? 'st' : p === 2 ? 'nd' : p === 3 ? 'rd' : 'th'}`}
              value={pickem.scoring.placement_points[p]}
              onChange={(v) => setScoring({ placement_points: { ...pickem.scoring.placement_points, [p]: v } })}
            />
          ))}
        </div>
      </Card>

      <Card className="p-5">
        <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Win & bonus points</h3>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
          <NumCell label="Win (champ)" value={pickem.scoring.win_points.championship} onChange={(v) => setScoring({ win_points: { ...pickem.scoring.win_points, championship: v } })} />
          <NumCell label="Win (cons)" value={pickem.scoring.win_points.consolation} onChange={(v) => setScoring({ win_points: { ...pickem.scoring.win_points, consolation: v } })} />
          <NumCell label="Fall bonus" value={pickem.scoring.bonus_points.fall} onChange={(v) => setScoring({ bonus_points: { ...pickem.scoring.bonus_points, fall: v } })} />
          <NumCell label="TF bonus" value={pickem.scoring.bonus_points.tech_fall} onChange={(v) => setScoring({ bonus_points: { ...pickem.scoring.bonus_points, tech_fall: v } })} />
          <NumCell label="Major bonus" value={pickem.scoring.bonus_points.major} onChange={(v) => setScoring({ bonus_points: { ...pickem.scoring.bonus_points, major: v } })} />
        </div>
      </Card>

      <Card className="p-5">
        <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Tiebreaker labels</h3>
        <div className="grid gap-3 sm:grid-cols-3">
          {pickem.tiebreakers.map((t, i) => (
            <label key={t.key} className="block">
              <span className="mb-1 block text-[10px] font-bold uppercase tracking-wider text-ink-500">Tiebreaker {i + 1}</span>
              <input
                value={t.label}
                onChange={(e) =>
                  setPickem((p) => ({
                    ...p,
                    tiebreakers: p.tiebreakers.map((x, j) => (j === i ? { ...x, label: e.target.value } : x)),
                  }))
                }
                className="h-10 w-full rounded-xl border border-mat-600 bg-mat-800 px-3 text-sm text-ink-100 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
              />
            </label>
          ))}
        </div>
      </Card>
    </div>
  )
}

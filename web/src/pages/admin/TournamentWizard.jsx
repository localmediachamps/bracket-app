import React, { useMemo, useState } from 'react'
import { useNavigate, useSearchParams, Link } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import {
  ArrowLeft, ArrowRight, Check, Hammer, Plus, Sparkles, Trash2, Trophy,
  AlertCircle, AlertTriangle, UploadCloud, Swords, Coins,
} from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Button, Card, Input, Select, Switch } from '../../components/ui'
import { cn } from '../../lib/utils'
import { PageHeader } from '../../components/admin/AdminCommon'
import CompetitorTable from '../../components/admin/CompetitorTable'
import PasteCompetitors from '../../components/admin/PasteCompetitors'
import ImportFlow from '../../components/admin/import/ImportFlow'
import {
  TEMPLATES, defaultPickemConfig, defaultScoringConfig, errMsg, nextKey,
  SCORING_PRESETS, templateLabel, toIso, validateCompetitors,
} from '../../components/admin/adminUtils'

const MANUAL_STEPS = ['Basics', 'Weights', 'Scoring', 'Review']
const PDF_STEPS = ['Basics', 'Upload & parse', 'Review import']
const DEMO_WEIGHTS = [125, 133, 141, 149, 157, 165, 174, 184, 197, 285]

export default function TournamentWizard() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const [path, setPath] = useState(searchParams.get('mode') === 'pdf' ? 'pdf' : null)
  const [step, setStep] = useState(0)

  /* ── basics ── */
  const [basics, setBasics] = useState({
    name: '', year: new Date().getFullYear(), location: '',
    start_date: '', end_date: '', locks_at: '',
    visibility: 'public', modes: { bracket: true, pickem: false },
  })

  /* ── weights ── */
  const [weights, setWeights] = useState([])

  /* ── scoring ── */
  const [scoring, setScoring] = useState(() => defaultScoringConfig())
  const [pickem, setPickem] = useState(() => defaultPickemConfig())
  const [activePreset, setActivePreset] = useState('ncaa')

  /* ── pdf draft tournament ── */
  const [draftId, setDraftId] = useState(null)

  const sortedWeights = useMemo(
    () => [...weights].sort((a, b) => (Number(a.weight) || 9999) - (Number(b.weight) || 9999)),
    [weights]
  )
  const weightIssues = useMemo(() => {
    const m = new Map()
    for (const w of weights) m.set(w.key, validateCompetitors(w.competitors))
    return m
  }, [weights])

  /* ── validation per step ── */
  const basicsValid = basics.name.trim().length >= 3 && Number(basics.year) > 1900
  const weightsValid =
    weights.length > 0 &&
    weights.every((w) => Number(w.weight) > 0) &&
    [...weightIssues.values()].every((iss) => !iss.some((i) => i.level === 'error'))

  const createMut = useMutation({
    mutationFn: (payload) => api.adminCreateTournament(payload),
    onError: (e) => toast.error('Create failed', { body: errMsg(e) }),
  })

  const createDraftMut = useMutation({
    mutationFn: () => api.adminCreateTournament({ name: basics.name.trim(), year: Number(basics.year), weight_classes: [] }),
    onSuccess: (res) => {
      const id = res?.id ?? res?.tournament?.id
      setDraftId(id)
      setStep(1)
    },
    onError: (e) => toast.error('Could not create draft tournament', { body: errMsg(e) }),
  })

  const submitManual = () => {
    const payload = {
      name: basics.name.trim(),
      year: Number(basics.year),
      location: basics.location.trim() || undefined,
      start_date: basics.start_date || undefined,
      end_date: basics.end_date || undefined,
      locks_at: toIso(basics.locks_at),
      visibility: basics.visibility,
      game_modes: Object.entries(basics.modes).filter(([, v]) => v).map(([k]) => k),
      scoring_config: { ...scoring, version: 1 },
      pickem_config: basics.modes.pickem ? pickem : undefined,
      weight_classes: sortedWeights.map((w) => ({
        weight: Number(w.weight),
        template: w.template,
        consolation_mode: w.consolation ? 'full' : 'none',
        competitors: w.competitors.map((c) => ({
          seed: Number(c.seed),
          name: String(c.name || '').trim(),
          school: String(c.school || '').trim(),
          record: String(c.record || '').trim() || undefined,
        })),
      })),
    }
    createMut.mutate(payload, {
      onSuccess: (res) => {
        const id = res?.id ?? res?.tournament?.id
        toast.success('Tournament created', { body: 'It is in draft — publish when ready.' })
        navigate(id ? `/admin/tournaments/${id}` : '/admin')
      },
    })
  }

  /* ── Path chooser ── */
  if (!path) {
    return (
      <div>
        <PageHeader title="New Tournament" sub="Two ways onto the mat — pick your path." />
        <div className="grid gap-4 sm:grid-cols-2">
          <PathCard
            icon={<UploadCloud size={26} />}
            title="Upload PDF bracket"
            body="Drop an official bracket PDF. The AI extracts weights, seeds, names and schools — you review, then we build the brackets."
            cta="Start with a PDF"
            onClick={() => setPath('pdf')}
            delay={0}
          />
          <PathCard
            icon={<Hammer size={26} />}
            title="Build manually"
            body="Full control: basics, weight classes, quick-paste competitor lists, templates and scoring — step by step."
            cta="Build it myself"
            onClick={() => setPath('manual')}
            delay={0.06}
          />
        </div>
      </div>
    )
  }

  const steps = path === 'pdf' ? PDF_STEPS : MANUAL_STEPS

  return (
    <div>
      <PageHeader
        title="New Tournament"
        sub={path === 'pdf' ? 'PDF import — review everything before it goes live.' : 'Manual build — four steps to a draft tournament.'}
        actions={
          <Button variant="ghost" size="sm" onClick={() => { setPath(null); setStep(0) }}>
            <ArrowLeft size={14} /> Change path
          </Button>
        }
      />

      <Stepper steps={steps} current={step} />

      {path === 'pdf' ? (
        <PdfPath
          step={step}
          setStep={setStep}
          basics={basics}
          setBasics={setBasics}
          basicsValid={basicsValid}
          draftId={draftId}
          createDraftMut={createDraftMut}
          onConfirmed={() => {
            toast.success('Tournament imported', { body: 'Review the generated brackets in the Builder.' })
            navigate(draftId ? `/admin/tournaments/${draftId}/builder` : '/admin')
          }}
        />
      ) : (
        <ManualPath
          step={step}
          setStep={setStep}
          basics={basics}
          setBasics={setBasics}
          basicsValid={basicsValid}
          weights={weights}
          setWeights={setWeights}
          sortedWeights={sortedWeights}
          weightIssues={weightIssues}
          weightsValid={weightsValid}
          scoring={scoring}
          setScoring={setScoring}
          pickem={pickem}
          setPickem={setPickem}
          activePreset={activePreset}
          setActivePreset={setActivePreset}
          createMut={createMut}
          submitManual={submitManual}
          setPath={setPath}
        />
      )}
    </div>
  )
}

/* ── Path chooser card ──────────────────────────────── */
function PathCard({ icon, title, body, cta, onClick, delay }) {
  return (
    <motion.button
      type="button"
      onClick={onClick}
      initial={{ opacity: 0, y: 14 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay }}
      className="group relative overflow-hidden rounded-2xl border border-mat-700 bg-mat-850 p-7 text-left transition-all hover:-translate-y-1 hover:border-gold-500/50 hover:shadow-glow"
    >
      <div className="bg-arena pointer-events-none absolute inset-0 opacity-60" />
      <span className="relative flex h-14 w-14 items-center justify-center rounded-2xl bg-mat-800 text-gold-500 transition-colors group-hover:bg-gold-500 group-hover:text-mat-950">
        {icon}
      </span>
      <h3 className="relative mt-5 font-display text-lg uppercase tracking-wide text-ink-100">{title}</h3>
      <p className="relative mt-2 text-sm leading-relaxed text-ink-500">{body}</p>
      <span className="relative mt-5 inline-flex items-center gap-1.5 text-sm font-bold text-gold-400">
        {cta} <ArrowRight size={15} className="transition-transform group-hover:translate-x-1" />
      </span>
    </motion.button>
  )
}

/* ── Stepper ────────────────────────────────────────── */
function Stepper({ steps, current }) {
  return (
    <ol className="mb-7 flex items-center gap-1 overflow-x-auto no-scrollbar" aria-label="Wizard progress">
      {steps.map((label, i) => {
        const done = i < current
        const active = i === current
        return (
          <li key={label} className="flex shrink-0 items-center gap-1">
            <span
              className={cn(
                'flex items-center gap-2 rounded-full px-3 py-1.5 text-xs font-bold transition-colors',
                active ? 'bg-gold-500 text-mat-950' : done ? 'bg-mat-800 text-pin-400' : 'bg-mat-850 text-ink-500'
              )}
            >
              <span className={cn(
                'flex h-[18px] w-[18px] items-center justify-center rounded-full text-[10px]',
                active ? 'bg-mat-950/15' : done ? 'bg-pin-500/15' : 'bg-mat-700'
              )}>
                {done ? <Check size={11} strokeWidth={3.5} /> : i + 1}
              </span>
              {label}
            </span>
            {i < steps.length - 1 && <span className="mx-1 h-px w-6 bg-mat-700" />}
          </li>
        )
      })}
    </ol>
  )
}

/* ── PDF path ───────────────────────────────────────── */
function PdfPath({ step, basics, setBasics, basicsValid, draftId, createDraftMut, onConfirmed }) {
  if (step === 0) {
    return (
      <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}>
        <Card className="mx-auto max-w-lg p-6">
          <h3 className="mb-1 font-display text-sm uppercase tracking-wide text-ink-100">Name the tournament first</h3>
          <p className="mb-5 text-sm text-ink-500">
            The PDF needs a tournament to attach to. We create a draft now — you can edit everything after import.
          </p>
          <div className="space-y-4">
            <Input
              label="Tournament name"
              value={basics.name}
              onChange={(e) => setBasics((b) => ({ ...b, name: e.target.value }))}
              placeholder="2026 NCAA Division I Championships"
              autoFocus
            />
            <Input
              label="Year"
              type="number"
              value={basics.year}
              onChange={(e) => setBasics((b) => ({ ...b, year: e.target.value }))}
            />
            <div className="flex justify-end">
              <Button
                variant="primary"
                disabled={!basicsValid}
                loading={createDraftMut.isPending}
                onClick={() => createDraftMut.mutate()}
              >
                Create draft & continue <ArrowRight size={15} />
              </Button>
            </div>
          </div>
        </Card>
      </motion.div>
    )
  }
  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}>
      <div className="mb-4 flex items-center gap-2 rounded-xl border border-mat-700 bg-mat-850 px-4 py-3 text-sm">
        <Trophy size={15} className="shrink-0 text-gold-500" />
        <span className="text-ink-300">
          Importing into <strong className="text-ink-100">{basics.name}</strong>
          <span className="ml-2 font-mono text-xs text-ink-600">draft #{draftId}</span>
        </span>
      </div>
      <ImportFlow tournamentId={draftId} onConfirmed={onConfirmed} />
    </motion.div>
  )
}

/* ── Manual path ────────────────────────────────────── */
function ManualPath(props) {
  const { step } = props
  return (
    <motion.div key={step} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}>
      {step === 0 && <BasicsStep {...props} />}
      {step === 1 && <WeightsStep {...props} />}
      {step === 2 && <ScoringStep {...props} />}
      {step === 3 && <ReviewStep {...props} />}
    </motion.div>
  )
}

function StepNav({ onBack, onNext, nextDisabled, nextLabel = 'Continue', nextLoading }) {
  return (
    <div className="mt-6 flex items-center justify-between">
      <Button variant="ghost" onClick={onBack}><ArrowLeft size={15} /> Back</Button>
      <Button variant="primary" onClick={onNext} disabled={nextDisabled} loading={nextLoading}>
        {nextLabel} <ArrowRight size={15} />
      </Button>
    </div>
  )
}

/* ── Step 1: basics ─────────────────────────────────── */
function BasicsStep({ basics, setBasics, basicsValid, setStep, setPath }) {
  const set = (k) => (e) => setBasics((b) => ({ ...b, [k]: e.target.value }))
  return (
    <div>
      <Card className="p-6">
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <Input label="Tournament name" value={basics.name} onChange={set('name')} placeholder="2026 NCAA Division I Championships" autoFocus />
          </div>
          <Input label="Year" type="number" value={basics.year} onChange={set('year')} />
          <Input label="Location" value={basics.location} onChange={set('location')} placeholder="Cleveland, OH" />
          <Input label="Start date" type="date" value={basics.start_date} onChange={set('start_date')} />
          <Input label="End date" type="date" value={basics.end_date} onChange={set('end_date')} />
          <div className="sm:col-span-2">
            <Input
              label="Prediction deadline (locks at)"
              type="datetime-local"
              value={basics.locks_at}
              onChange={set('locks_at')}
              hint="Picks lock automatically at this time."
            />
          </div>
        </div>

        <div className="mt-5">
          <Switch
            checked={basics.visibility === 'public'}
            onChange={(v) => setBasics((b) => ({ ...b, visibility: v ? 'public' : 'unlisted' }))}
            label="Public visibility"
            description={basics.visibility === 'public' ? 'Listed in the tournament directory.' : 'Unlisted — reachable only by direct link.'}
          />
        </div>

        <p className="mb-2 mt-6 text-xs font-bold uppercase tracking-wider text-ink-500">Game modes</p>
        <div className="grid gap-3 sm:grid-cols-2">
          <ModeCard
            icon={<Swords size={18} />}
            title="Bracket Challenge"
            body="Players predict every match in every weight."
            checked={basics.modes.bracket}
            onToggle={() => setBasics((b) => ({ ...b, modes: { ...b.modes, bracket: !b.modes.bracket } }))}
          />
          <ModeCard
            icon={<Coins size={18} />}
            title="Pick'em Showdown"
            body="Salary-cap: one wrestler per weight within budget."
            checked={basics.modes.pickem}
            onToggle={() => setBasics((b) => ({ ...b, modes: { ...b.modes, pickem: !b.modes.pickem } }))}
          />
        </div>
      </Card>
      <StepNav onBack={() => setPath(null)} onNext={() => setStep(1)} nextDisabled={!basicsValid} />
    </div>
  )
}

function ModeCard({ icon, title, body, checked, onToggle }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={onToggle}
      className={cn(
        'flex items-start gap-3 rounded-xl border p-4 text-left transition-all',
        checked ? 'border-gold-500/60 bg-gold-500/8' : 'border-mat-700 bg-mat-800 hover:border-mat-500'
      )}
    >
      <span className={cn('flex h-10 w-10 shrink-0 items-center justify-center rounded-xl', checked ? 'bg-gold-500 text-mat-950' : 'bg-mat-700 text-ink-400')}>
        {icon}
      </span>
      <span className="min-w-0 flex-1">
        <span className="flex items-center justify-between gap-2">
          <span className="text-sm font-bold text-ink-100">{title}</span>
          <span className={cn('flex h-5 w-5 items-center justify-center rounded-full border', checked ? 'border-gold-500 bg-gold-500 text-mat-950' : 'border-mat-600 text-transparent')}>
            <Check size={12} strokeWidth={4} />
          </span>
        </span>
        <span className="mt-0.5 block text-xs text-ink-500">{body}</span>
      </span>
    </button>
  )
}

/* ── Step 2: weights ────────────────────────────────── */
function WeightsStep({ weights, setWeights, sortedWeights, weightIssues, weightsValid, setStep }) {
  const [pasteFor, setPasteFor] = useState(null)

  const addWeight = () => setWeights((ws) => [...ws, { key: nextKey(), weight: '', template: 'ncaa_33', consolation: true, competitors: [] }])
  const loadDemo = () =>
    setWeights(DEMO_WEIGHTS.map((w) => ({ key: nextKey(), weight: String(w), template: 'ncaa_33', consolation: true, competitors: [] })))
  const update = (key, patch) => setWeights((ws) => ws.map((w) => (w.key === key ? { ...w, ...patch } : w)))
  const remove = (key) => setWeights((ws) => ws.filter((w) => w.key !== key))

  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm text-ink-500">
          {weights.length === 0 ? 'Add weight classes, then paste or type each competitor list.' : `${weights.length} weight${weights.length === 1 ? '' : 's'} · ordered lightest → heaviest automatically`}
        </p>
        <div className="flex gap-2">
          <Button variant="secondary" size="sm" onClick={loadDemo}>
            <Sparkles size={14} /> Load demo 10 weights
          </Button>
          <Button variant="primary" size="sm" onClick={addWeight}>
            <Plus size={14} /> Add weight
          </Button>
        </div>
      </div>

      {weights.length === 0 ? (
        <button
          type="button"
          onClick={addWeight}
          className="flex w-full flex-col items-center gap-3 rounded-2xl border-2 border-dashed border-mat-600 py-14 text-ink-500 transition-colors hover:border-gold-500/50 hover:text-gold-400"
        >
          <Plus size={26} />
          <span className="font-display text-sm uppercase tracking-wide">Add your first weight class</span>
        </button>
      ) : (
        <div className="space-y-4">
          {sortedWeights.map((w) => {
            const issues = weightIssues.get(w.key) ?? []
            const errs = issues.filter((i) => i.level === 'error').length
            const warns = issues.filter((i) => i.level === 'warn').length
            return (
              <Card key={w.key} className={cn('p-5', errs > 0 && 'border-blood-500/40')}>
                <div className="mb-4 flex flex-wrap items-center gap-3">
                  <div className="flex items-center gap-2">
                    <input
                      type="number"
                      value={w.weight}
                      min={1}
                      onChange={(e) => update(w.key, { weight: e.target.value })}
                      aria-label="Weight in pounds"
                      placeholder="125"
                      className="h-10 w-24 rounded-xl border border-mat-600 bg-mat-800 px-3 text-center font-mono text-sm font-bold text-gold-400 placeholder:text-ink-600 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
                    />
                    <span className="text-xs font-bold uppercase tracking-wider text-ink-500">lbs</span>
                  </div>
                  <div className="w-60 max-w-full">
                    <Select value={w.template} onChange={(e) => update(w.key, { template: e.target.value })} aria-label="Bracket template" className="h-10">
                      {TEMPLATES.map((t) => (
                        <option key={t.value} value={t.value}>{t.label}</option>
                      ))}
                    </Select>
                  </div>
                  <button
                    type="button"
                    role="switch"
                    aria-checked={w.consolation}
                    onClick={() => update(w.key, { consolation: !w.consolation })}
                    className="flex items-center gap-2 rounded-lg border border-mat-700 bg-mat-800 px-3 py-2 text-xs font-bold text-ink-300 transition-colors hover:border-mat-500"
                  >
                    <span className={cn('relative h-[18px] w-8 rounded-full transition-colors', w.consolation ? 'bg-gold-500' : 'bg-mat-600')}>
                      <span className={cn('absolute top-[2px] h-[14px] w-[14px] rounded-full bg-white transition-transform', w.consolation ? 'translate-x-[14px]' : 'translate-x-[2px]')} />
                    </span>
                    Consolation
                  </button>
                  <span className="text-xs text-ink-500">
                    {w.competitors.length} wrestler{w.competitors.length === 1 ? '' : 's'}
                  </span>
                  {errs > 0 && <span className="inline-flex items-center gap-1 text-xs font-semibold text-blood-400"><AlertCircle size={12} /> {errs} error{errs === 1 ? '' : 's'}</span>}
                  {errs === 0 && warns > 0 && <span className="inline-flex items-center gap-1 text-xs font-semibold text-gold-400"><AlertTriangle size={12} /> {warns}</span>}
                  <button
                    type="button"
                    onClick={() => remove(w.key)}
                    aria-label={`Remove weight ${w.weight || '(unset)'}`}
                    className="ml-auto rounded-lg p-2 text-ink-600 transition-colors hover:bg-blood-500/15 hover:text-blood-400"
                  >
                    <Trash2 size={15} />
                  </button>
                </div>

                <div className="mb-3 flex items-center gap-2">
                  <Button variant="secondary" size="xs" onClick={() => setPasteFor(pasteFor === w.key ? null : w.key)}>
                    {pasteFor === w.key ? 'Hide quick-paste' : 'Quick-paste list'}
                  </Button>
                </div>
                {pasteFor === w.key && (
                  <div className="mb-4 rounded-xl border border-mat-700 bg-mat-900/50 p-4">
                    <PasteCompetitors
                      appendable={w.competitors.length > 0}
                      onApply={(rows, { append }) => {
                        update(w.key, { competitors: append ? [...w.competitors, ...rows] : rows })
                        setPasteFor(null)
                      }}
                    />
                  </div>
                )}

                {w.competitors.length > 0 && issues.length > 0 && (
                  <ul className="mb-3 flex max-h-24 flex-col gap-1 overflow-y-auto rounded-lg border border-mat-700 bg-mat-900/60 p-3 text-xs">
                    {issues.map((it, i) => (
                      <li key={i} className={cn('flex items-center gap-1.5', it.level === 'error' ? 'text-blood-400' : 'text-gold-400')}>
                        {it.level === 'error' ? <AlertCircle size={12} /> : <AlertTriangle size={12} />} {it.message}
                      </li>
                    ))}
                  </ul>
                )}

                {w.competitors.length > 0 || pasteFor !== w.key ? (
                  <CompetitorTable rows={w.competitors} issues={issues} onChange={(rows) => update(w.key, { competitors: rows })} />
                ) : (
                  <p className="rounded-lg border border-dashed border-mat-700 px-4 py-6 text-center text-xs text-ink-600">
                    No wrestlers yet — paste a list above.
                  </p>
                )}
              </Card>
            )
          })}
          <button
            type="button"
            onClick={addWeight}
            className="flex w-full items-center justify-center gap-2 rounded-xl border border-dashed border-mat-600 py-3 text-sm font-bold text-ink-400 transition-colors hover:border-gold-500/50 hover:text-gold-400"
          >
            <Plus size={15} /> Add another weight
          </button>
        </div>
      )}
      <StepNav onBack={() => setStep(0)} onNext={() => setStep(2)} nextDisabled={!weightsValid} />
    </div>
  )
}

/* ── Step 3: scoring ────────────────────────────────── */
function NumCell({ label, value, onChange, hint }) {
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
      {hint && <span className="mt-0.5 block text-[10px] text-ink-600">{hint}</span>}
    </label>
  )
}

function ScoringStep({ scoring, setScoring, pickem, setPickem, activePreset, setActivePreset, basics, setStep }) {
  const setB = (patch) => setScoring((s) => ({ ...s, bracket: { ...s.bracket, ...patch } }))
  const setRound = (section, round, v) => setScoring((s) => ({ ...s, bracket: { ...s.bracket, [section]: { ...s.bracket[section], [round]: v } } }))
  const setPlace = (code, v) => setScoring((s) => ({ ...s, bracket: { ...s.bracket, placement: { ...s.bracket.placement, [code]: v } } }))

  const applyPreset = (p) => {
    setActivePreset(p.key)
    setScoring((s) => ({ ...s, bracket: JSON.parse(JSON.stringify(p.config)) }))
  }

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-3">
        {SCORING_PRESETS.map((p) => (
          <button
            key={p.key}
            type="button"
            onClick={() => applyPreset(p)}
            className={cn(
              'rounded-xl border p-4 text-left transition-all',
              activePreset === p.key ? 'border-gold-500/60 bg-gold-500/8' : 'border-mat-700 bg-mat-850 hover:border-mat-500'
            )}
          >
            <span className="flex items-center justify-between">
              <span className="text-sm font-bold text-ink-100">{p.label}</span>
              {activePreset === p.key && <Check size={15} className="text-gold-400" />}
            </span>
            <span className="mt-1 block text-xs text-ink-500">{p.blurb}</span>
          </button>
        ))}
      </div>

      <Card className="p-5">
        <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Championship rounds</h3>
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-6">
          {[1, 2, 3, 4, 5, 6].map((r) => (
            <NumCell
              key={r}
              label={`Round ${r}`}
              hint={r === 6 ? 'finals (64)' : r === 5 ? 'finals (32)' : r === 4 ? 'semis' : r === 3 ? 'quarters' : undefined}
              value={scoring.bracket.championship[r]}
              onChange={(v) => setRound('championship', r, v)}
            />
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

      {basics.modes.pickem && (
        <Card className="p-5">
          <h3 className="mb-1 font-display text-sm uppercase tracking-wide text-ink-100">Pick'em config</h3>
          <p className="mb-4 text-xs text-ink-500">Salary-cap mode — one wrestler per weight within budget.</p>
          <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <NumCell label="Budget" value={pickem.budget} onChange={(v) => setPickem((p) => ({ ...p, budget: v }))} />
          </div>
          <p className="mb-2 text-[10px] font-bold uppercase tracking-wider text-ink-500">Cost by seed</p>
          <div className="mb-5 grid grid-cols-4 gap-2 sm:grid-cols-9">
            {[...Array(16)].map((_, i) => i + 1).map((s) => (
              <NumCell
                key={s}
                label={`#${s}`}
                value={pickem.seed_costs[s]}
                onChange={(v) => setPickem((p) => ({ ...p, seed_costs: { ...p.seed_costs, [s]: v } }))}
              />
            ))}
            <NumCell label="Default" value={pickem.seed_costs.default} onChange={(v) => setPickem((p) => ({ ...p, seed_costs: { ...p.seed_costs, default: v } }))} />
          </div>
          <p className="mb-2 text-[10px] font-bold uppercase tracking-wider text-ink-500">Placement points</p>
          <div className="mb-5 grid grid-cols-4 gap-2 sm:grid-cols-8">
            {[1, 2, 3, 4, 5, 6, 7, 8].map((p) => (
              <NumCell
                key={p}
                label={`${p}${p === 1 ? 'st' : p === 2 ? 'nd' : p === 3 ? 'rd' : 'th'}`}
                value={pickem.scoring.placement_points[p]}
                onChange={(v) => setPickem((pk) => ({ ...pk, scoring: { ...pk.scoring, placement_points: { ...pk.scoring.placement_points, [p]: v } } }))}
              />
            ))}
          </div>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
            <NumCell label="Win (champ)" value={pickem.scoring.win_points.championship} onChange={(v) => setPickem((pk) => ({ ...pk, scoring: { ...pk.scoring, win_points: { ...pk.scoring.win_points, championship: v } } }))} />
            <NumCell label="Win (cons)" value={pickem.scoring.win_points.consolation} onChange={(v) => setPickem((pk) => ({ ...pk, scoring: { ...pk.scoring, win_points: { ...pk.scoring.win_points, consolation: v } } }))} />
            <NumCell label="Fall bonus" value={pickem.scoring.bonus_points.fall} onChange={(v) => setPickem((pk) => ({ ...pk, scoring: { ...pk.scoring, bonus_points: { ...pk.scoring.bonus_points, fall: v } } }))} />
            <NumCell label="TF bonus" value={pickem.scoring.bonus_points.tech_fall} onChange={(v) => setPickem((pk) => ({ ...pk, scoring: { ...pk.scoring, bonus_points: { ...pk.scoring.bonus_points, tech_fall: v } } }))} />
            <NumCell label="Major bonus" value={pickem.scoring.bonus_points.major} onChange={(v) => setPickem((pk) => ({ ...pk, scoring: { ...pk.scoring, bonus_points: { ...pk.scoring.bonus_points, major: v } } }))} />
          </div>
        </Card>
      )}

      <StepNav onBack={() => setStep(1)} onNext={() => setStep(3)} />
    </div>
  )
}

/* ── Step 4: review ─────────────────────────────────── */
function ReviewStep({ basics, sortedWeights, scoring, weightIssues, createMut, submitManual, setStep }) {
  const champ = [1, 2, 3, 4, 5, 6].map((r) => scoring.bracket.championship[r]).join(' / ')
  const cons = [1, 2, 3, 4, 5, 6, 7, 8].map((r) => scoring.bracket.consolation[r]).join(' / ')
  const totalWrestlers = sortedWeights.reduce((s, w) => s + w.competitors.length, 0)

  return (
    <div className="space-y-5">
      <Card className="p-5">
        <h3 className="mb-3 font-display text-sm uppercase tracking-wide text-ink-100">Tournament</h3>
        <dl className="grid gap-x-6 gap-y-2 text-sm sm:grid-cols-2">
          <Row k="Name" v={basics.name} />
          <Row k="Year" v={basics.year} />
          <Row k="Location" v={basics.location || '—'} />
          <Row k="Dates" v={basics.start_date ? `${basics.start_date}${basics.end_date ? ` → ${basics.end_date}` : ''}` : '—'} />
          <Row k="Locks at" v={basics.locks_at ? new Date(basics.locks_at).toLocaleString() : '—'} />
          <Row k="Visibility" v={basics.visibility} />
          <Row k="Modes" v={Object.entries(basics.modes).filter(([, v]) => v).map(([k]) => (k === 'bracket' ? 'Bracket Challenge' : "Pick'em")).join(' + ') || '—'} />
        </dl>
      </Card>

      <Card className="p-5">
        <h3 className="mb-3 font-display text-sm uppercase tracking-wide text-ink-100">
          Weights <span className="ml-1 font-mono text-xs text-ink-500">{sortedWeights.length} classes · {totalWrestlers} wrestlers</span>
        </h3>
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          {sortedWeights.map((w) => {
            const issues = weightIssues.get(w.key) ?? []
            const warns = issues.filter((i) => i.level === 'warn').length
            return (
              <div key={w.key} className="rounded-xl border border-mat-700 bg-mat-800/60 p-3.5">
                <div className="flex items-center justify-between">
                  <span className="font-mono text-sm font-bold text-gold-400">{w.weight} lbs</span>
                  <span className="font-mono text-xs text-ink-400">{w.competitors.length} wrestlers</span>
                </div>
                <p className="mt-1 truncate text-xs text-ink-500">{templateLabel(w.template)}{w.consolation ? '' : ' · no consolation'}</p>
                {warns > 0 && <p className="mt-1 flex items-center gap-1 text-[11px] font-semibold text-gold-400"><AlertTriangle size={11} /> {warns} warning{warns === 1 ? '' : 's'}</p>}
              </div>
            )
          })}
        </div>
      </Card>

      <Card className="p-5">
        <h3 className="mb-3 font-display text-sm uppercase tracking-wide text-ink-100">Scoring</h3>
        <dl className="space-y-2 text-sm">
          <Row k="Championship R1–R6" v={<span className="font-mono">{champ}</span>} />
          <Row k="Consolation R1–R8" v={<span className="font-mono">{cons}</span>} />
          <Row k="Placement 3/5/7" v={<span className="font-mono">{scoring.bracket.placement.place_3} / {scoring.bracket.placement.place_5} / {scoring.bracket.placement.place_7}</span>} />
          <Row k="Pigtail / champ bonus" v={<span className="font-mono">{scoring.bracket.pigtail} / +{scoring.bracket.champion_bonus}</span>} />
        </dl>
      </Card>

      {createMut.isError && (
        <Card className="flex items-center gap-2 border-blood-500/40 p-4 text-sm text-blood-400">
          <AlertCircle size={16} /> {errMsg(createMut.error)}
        </Card>
      )}

      <div className="flex items-center justify-between">
        <Button variant="ghost" onClick={() => setStep(2)}><ArrowLeft size={15} /> Back</Button>
        <Button variant="primary" size="lg" onClick={submitManual} loading={createMut.isPending}>
          <Trophy size={17} /> Create tournament
        </Button>
      </div>
      <p className="text-center text-xs text-ink-600">
        Creates a <strong>draft</strong> — nothing is visible to players until you publish. Prefer paper? <Link to="/admin/tournaments/new?mode=pdf" className="text-gold-400">Import a PDF instead</Link>.
      </p>
    </div>
  )
}

function Row({ k, v }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-mat-700/50 pb-1.5">
      <dt className="text-xs font-bold uppercase tracking-wider text-ink-500">{k}</dt>
      <dd className="text-right text-ink-200">{v}</dd>
    </div>
  )
}

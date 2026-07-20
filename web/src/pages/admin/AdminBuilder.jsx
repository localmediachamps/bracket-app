import React, { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertCircle, AlertTriangle, CheckCircle2, ClipboardPaste, GitBranch, Info, Lock, Plus, Save,
} from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Button, Card, EmptyState, Modal, Select, Skeleton, StatusPill } from '../../components/ui'
import { cn } from '../../lib/utils'
import BracketView from '../../components/bracket/BracketView'
import { ErrorState, PageHeader } from '../../components/admin/AdminCommon'
import WeightTabs from '../../components/admin/WeightTabs'
import CompetitorTable from '../../components/admin/CompetitorTable'
import PasteCompetitors from '../../components/admin/PasteCompetitors'
import { errMsg, nextKey, stripRow, TEMPLATES, validateCompetitors } from '../../components/admin/adminUtils'

export default function AdminBuilder() {
  const { id } = useParams()
  const qc = useQueryClient()
  const [activeWc, setActiveWc] = useState(null)
  const [pasteOpen, setPasteOpen] = useState(false)
  const [addWeightOpen, setAddWeightOpen] = useState(false)

  const tQ = useQuery({ queryKey: ['admin', 'tournament', id], queryFn: () => api.adminTournament(id) })
  const tournament = tQ.data?.tournament ?? tQ.data
  const weights = useMemo(
    () =>
      (tQ.data?.weight_classes ?? tournament?.weight_classes ?? [])
        .slice()
        .sort((a, b) => (a.display_order ?? a.weight ?? 0) - (b.display_order ?? b.weight ?? 0)),
    [tQ.data, tournament]
  )
  const wcId = activeWc ?? weights[0]?.id

  const bQ = useQuery({
    queryKey: ['admin', 'bracket', id, wcId],
    queryFn: () => api.adminBracketView(id, wcId),
    enabled: !!wcId,
  })

  /* local competitor editing, seeded from the bracket view */
  const [rows, setRows] = useState([])
  const [dirty, setDirty] = useState(false)
  useEffect(() => {
    const comps = bQ.data?.competitors ?? []
    setRows(
      comps.map((c) => ({
        key: `srv-${c.id}`,
        seed: c.seed ?? '',
        name: c.name ?? '',
        school: c.school ?? '',
        record: c.record ?? '',
        withdrawn: !!c.withdrawn,
      }))
    )
    setDirty(false)
  }, [bQ.data, wcId])

  const issues = useMemo(() => validateCompetitors(rows), [rows])
  const errorCount = issues.filter((i) => i.level === 'error').length

  const invalidateAll = () => {
    qc.invalidateQueries({ queryKey: ['admin', 'bracket', id] })
    qc.invalidateQueries({ queryKey: ['admin', 'tournament', id] })
  }

  const saveMut = useMutation({
    mutationFn: () => api.adminSaveCompetitors(wcId, rows.map(stripRow)),
    onSuccess: () => {
      toast.success('Competitors saved')
      setDirty(false)
      invalidateAll()
    },
    onError: (e) => toast.error('Save failed', { body: errMsg(e) }),
  })

  /* bracket generation */
  const [template, setTemplate] = useState('ncaa_33')
  const [genIssues, setGenIssues] = useState(null)
  useEffect(() => {
    setTemplate(bQ.data?.weight_class?.template ?? bQ.data?.weight_class?.bracket_template ?? 'ncaa_33')
    setGenIssues(null)
  }, [bQ.data, wcId])

  const genMut = useMutation({
    mutationFn: () => api.adminGenerateBracket(wcId, template),
    onSuccess: (res) => {
      const list = Array.isArray(res) ? res : res?.issues ?? []
      setGenIssues(list)
      if (list.length === 0) toast.success('Bracket generated', { body: 'Self-check passed clean.' })
      else toast.info('Bracket generated with self-check notes', { body: `${list.length} issue${list.length === 1 ? '' : 's'} reported.` })
      invalidateAll()
    },
    onError: (e) => toast.error('Generation failed', { body: errMsg(e) }),
  })

  const addWeightMut = useMutation({
    mutationFn: (weight) => api.adminAddWeight(id, { weight: Number(weight), template: 'ncaa_33' }),
    onSuccess: () => {
      toast.success('Weight class added')
      setAddWeightOpen(false)
      invalidateAll()
    },
    onError: (e) => toast.error('Could not add weight', { body: errMsg(e) }),
  })

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

  const locked = tournament?.status && tournament.status !== 'draft'
  const wc = weights.find((w) => w.id === wcId)
  const matches = bQ.data?.matches ?? []

  return (
    <div>
      <PageHeader
        title="Bracket Builder"
        sub={`${tournament?.name ?? ''} · structure & competitors`}
        actions={
          <div className="flex items-center gap-2">
            <StatusPill status={tournament?.status} />
            <Button variant="secondary" size="sm" onClick={() => setAddWeightOpen(true)}>
              <Plus size={14} /> Add weight
            </Button>
          </div>
        }
      />

      {locked && (
        <Card className="mb-5 flex items-start gap-3 border-gold-500/40 bg-gold-500/5 p-4">
          <Lock size={16} className="mt-0.5 shrink-0 text-gold-400" />
          <p className="text-sm text-ink-300">
            <strong className="text-gold-300">Structure locked after publish.</strong> Competitors are editable only before results exist —
            the server will reject unsafe changes. Regenerating brackets is disabled.
          </p>
        </Card>
      )}

      {weights.length === 0 ? (
        <EmptyState
          icon={<GitBranch size={24} />}
          title="No weight classes yet"
          body="Add weight classes here, or import the whole bracket from a PDF."
          action={
            <div className="flex gap-2">
              <Button variant="secondary" onClick={() => setAddWeightOpen(true)}><Plus size={15} /> Add weight</Button>
              <Link to={`/admin/tournaments/${id}/import`}><Button variant="primary">Import PDF</Button></Link>
            </div>
          }
        />
      ) : (
        <>
          <WeightTabs className="mb-5" weights={weights} activeId={wcId} onChange={setActiveWc} />

          {/* competitors card */}
          <Card className="mb-5 p-5">
            <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
              <h2 className="font-display text-sm uppercase tracking-wide text-ink-100">
                {wc?.weight ?? ''} lbs — wrestlers
                <span className="ml-2 font-mono text-xs font-normal text-ink-500">{rows.length}</span>
              </h2>
              <div className="flex items-center gap-2">
                <Button variant="secondary" size="sm" onClick={() => setPasteOpen(true)}>
                  <ClipboardPaste size={14} /> Paste list
                </Button>
                <Button
                  variant="primary"
                  size="sm"
                  disabled={!dirty || errorCount > 0}
                  loading={saveMut.isPending}
                  onClick={() => saveMut.mutate()}
                >
                  <Save size={14} /> Save wrestlers
                </Button>
              </div>
            </div>

            {bQ.isLoading ? (
              <div className="space-y-2">
                <Skeleton className="h-10" /><Skeleton className="h-10" /><Skeleton className="h-10" />
              </div>
            ) : bQ.isError ? (
              <ErrorState error={bQ.error} onRetry={() => bQ.refetch()} title="Couldn't load weight class" />
            ) : (
              <>
                {issues.length > 0 && (
                  <ul className="mb-3 flex max-h-28 flex-col gap-1 overflow-y-auto rounded-lg border border-mat-700 bg-mat-900/60 p-3 text-xs">
                    {issues.map((it, i) => (
                      <li key={i} className={cn('flex items-center gap-1.5', it.level === 'error' ? 'text-blood-400' : 'text-gold-400')}>
                        {it.level === 'error' ? <AlertCircle size={12} /> : <AlertTriangle size={12} />} {it.message}
                      </li>
                    ))}
                  </ul>
                )}
                <CompetitorTable rows={rows} issues={issues} showWithdrawn onChange={(r) => { setRows(r); setDirty(true) }} />
                {dirty && (
                  <p className="mt-2 flex items-center gap-1.5 text-xs font-semibold text-gold-400">
                    <Info size={12} /> Unsaved changes{errorCount > 0 ? ` — fix ${errorCount} error${errorCount === 1 ? '' : 's'} to save` : ''}
                  </p>
                )}
              </>
            )}
          </Card>

          {/* generate card */}
          <Card className="mb-5 p-5">
            <div className="flex flex-wrap items-end gap-3">
              <div className="w-72 max-w-full">
                <Select label="Bracket template" value={template} onChange={(e) => setTemplate(e.target.value)}>
                  {TEMPLATES.map((t) => (
                    <option key={t.value} value={t.value}>{t.label}</option>
                  ))}
                </Select>
              </div>
              <Button
                variant={matches.length ? 'secondary' : 'primary'}
                onClick={() => genMut.mutate()}
                loading={genMut.isPending}
                disabled={locked || rows.length < 2}
              >
                <GitBranch size={15} /> {matches.length ? 'Regenerate bracket' : 'Generate bracket'}
              </Button>
              {matches.length > 0 && !locked && (
                <p className="text-xs text-ink-500">Regenerating deletes and rebuilds all matches for this weight.</p>
              )}
            </div>

            {genIssues && (
              <div className="mt-4">
                {genIssues.length === 0 ? (
                  <p className="flex items-center gap-1.5 rounded-lg border border-pin-500/30 bg-pin-500/8 px-3 py-2 text-xs font-semibold text-pin-400">
                    <CheckCircle2 size={13} /> Generator self-check passed — graph is sound.
                  </p>
                ) : (
                  <ul className="space-y-1.5">
                    {genIssues.map((it, i) => {
                      const sev = typeof it === 'string' ? 'warn' : it.severity ?? it.level ?? 'warn'
                      const msg = typeof it === 'string' ? it : it.message ?? JSON.stringify(it)
                      return (
                        <li
                          key={i}
                          className={cn(
                            'flex items-start gap-2 rounded-lg border px-3 py-2 text-xs',
                            sev === 'error' ? 'border-blood-500/40 bg-blood-500/8 text-blood-300' : 'border-gold-500/30 bg-gold-500/6 text-gold-300'
                          )}
                        >
                          <span className={cn(
                            'mt-0.5 shrink-0 rounded-full px-1.5 py-px text-[9px] font-bold uppercase',
                            sev === 'error' ? 'bg-blood-500/20 text-blood-400' : 'bg-gold-500/20 text-gold-400'
                          )}>
                            {sev}
                          </span>
                          {msg}
                        </li>
                      )
                    })}
                  </ul>
                )}
              </div>
            )}
          </Card>

          {/* preview */}
          <Card className="p-5">
            <h2 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Bracket preview</h2>
            {bQ.isLoading ? (
              <Skeleton className="h-72" />
            ) : matches.length === 0 ? (
              <EmptyState
                icon={<GitBranch size={24} />}
                title="No bracket yet"
                body={rows.length >= 2 ? 'Save wrestlers, then generate the bracket to preview it here.' : 'Add at least 2 wrestlers, then generate.'}
              />
            ) : (
              <BracketView data={bQ.data} mode="readonly" />
            )}
          </Card>
        </>
      )}

      {/* paste modal */}
      <Modal open={pasteOpen} onClose={() => setPasteOpen(false)} title={`Paste wrestlers — ${wc?.weight ?? ''} lbs`} wide>
        <PasteCompetitors
          appendable={rows.length > 0}
          onApply={(parsed, { append }) => {
            setRows((r) => (append ? [...r, ...parsed] : parsed.map((p) => ({ ...p, key: p.key ?? nextKey() }))))
            setDirty(true)
            setPasteOpen(false)
          }}
        />
      </Modal>

      {/* add weight modal */}
      <AddWeightModal
        open={addWeightOpen}
        onClose={() => setAddWeightOpen(false)}
        loading={addWeightMut.isPending}
        onSubmit={(w) => addWeightMut.mutate(w)}
      />
    </div>
  )
}

function AddWeightModal({ open, onClose, onSubmit, loading }) {
  const [weight, setWeight] = useState('')
  useEffect(() => {
    if (open) setWeight('')
  }, [open])
  return (
    <Modal open={open} onClose={onClose} title="Add weight class">
      <form
        onSubmit={(e) => {
          e.preventDefault()
          if (Number(weight) > 0) onSubmit(weight)
        }}
        className="space-y-4"
      >
        <label className="block">
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">Weight (lbs)</span>
          <input
            type="number"
            min={1}
            value={weight}
            onChange={(e) => setWeight(e.target.value)}
            placeholder="125"
            autoFocus
            className="h-11 w-full rounded-xl border border-mat-600 bg-mat-800 px-3.5 font-mono text-sm font-bold text-ink-100 placeholder:text-ink-600 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
          />
        </label>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" type="button" onClick={onClose}>Cancel</Button>
          <Button variant="primary" type="submit" disabled={!(Number(weight) > 0)} loading={loading}>
            <Plus size={15} /> Add weight
          </Button>
        </div>
      </form>
    </Modal>
  )
}

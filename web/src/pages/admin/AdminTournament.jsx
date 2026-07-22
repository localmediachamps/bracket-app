import React, { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import {
  Hammer, FileUp, ListChecks, SlidersHorizontal, BarChart3, Download,
  Lock, Play, Archive, RotateCcw, Ban, CheckCircle2, XCircle, Trophy, Users, Layers, ShieldAlert,
} from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Button, Card, Countdown, Skeleton, Stat, StatusPill } from '../../components/ui'
import { formatDateTime, plural } from '../../lib/utils'
import { ConfirmModal, ErrorState, PageHeader } from '../../components/admin/AdminCommon'
import { downloadJson, errMsg } from '../../components/admin/adminUtils'

/* Transition definitions per status (state machine §4) */
const TRANSITIONS = {
  draft: [
    { action: 'publish', label: 'Publish tournament', icon: CheckCircle2, variant: 'primary', confirm: true, blurb: 'Goes live in the directory — players can start making picks.' },
  ],
  open: [
    { action: 'lock', label: 'Lock now', icon: Lock, variant: 'primary', confirm: true, blurb: 'Stops all pick changes immediately (deadline also locks automatically).' },
  ],
  locked: [
    { action: 'start', label: 'Start tournament', icon: Play, variant: 'primary', confirm: true, blurb: 'Flips to LIVE — result entry and scoring begin.' },
    { action: 'reopen', label: 'Reopen', icon: RotateCcw, variant: 'secondary', reason: true, blurb: 'Back to open — picks editable again.' },
  ],
  live: [
    { action: 'complete', label: 'Mark completed', icon: CheckCircle2, variant: 'primary', confirm: true, blurb: 'Finalizes standings. Fails if matches are still pending.' },
    { action: 'reopen', label: 'Reopen', icon: RotateCcw, variant: 'secondary', reason: true, blurb: 'Back to open — picks editable again.' },
  ],
  completed: [
    { action: 'archive', label: 'Archive', icon: Archive, variant: 'secondary', confirm: true, blurb: 'Hidden from the directory; direct links keep working. Never deleted.' },
  ],
}

export default function AdminTournament() {
  const { id } = useParams()
  const qc = useQueryClient()
  const [pendingAction, setPendingAction] = useState(null) // transition object
  const [cancelOpen, setCancelOpen] = useState(false)
  const [exporting, setExporting] = useState(false)

  const tQ = useQuery({
    queryKey: ['admin', 'tournament', id],
    queryFn: () => api.adminTournament(id),
  })
  const t = tQ.data
  const tournament = t?.tournament ?? t
  const weights = (t?.weight_classes ?? tournament?.weight_classes ?? []).slice().sort(
    (a, b) => (a.display_order ?? a.weight ?? 0) - (b.display_order ?? b.weight ?? 0)
  )

  const statusMut = useMutation({
    mutationFn: ({ action, reason }) =>
      action === 'publish' ? api.adminPublishTournament(id) : api.adminTournamentStatus(id, action, reason),
    onSuccess: (_d, vars) => {
      toast.success(`Status updated`, { body: `Action "${vars.action}" applied.` })
      setPendingAction(null)
      setCancelOpen(false)
      qc.invalidateQueries({ queryKey: ['admin', 'tournament', id] })
      qc.invalidateQueries({ queryKey: ['admin', 'tournaments'] })
    },
    onError: (e) => {
      toast.error('Transition failed', { body: errMsg(e) })
      setPendingAction(null)
      setCancelOpen(false)
    },
  })

  const doExport = async () => {
    setExporting(true)
    try {
      const data = await api.adminExport(id)
      downloadJson(data, `tournament-${id}-export.json`)
      toast.success('Export downloaded')
    } catch (e) {
      toast.error('Export failed', { body: errMsg(e) })
    } finally {
      setExporting(false)
    }
  }

  if (tQ.isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-10 w-80" />
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <Skeleton className="h-[92px]" /><Skeleton className="h-[92px]" /><Skeleton className="h-[92px]" /><Skeleton className="h-[92px]" />
        </div>
        <Skeleton className="h-44" />
      </div>
    )
  }
  if (tQ.isError) return <ErrorState error={tQ.error} onRetry={() => tQ.refetch()} title="Couldn't load tournament" />

  const status = tournament?.status ?? 'draft'
  const transitions = TRANSITIONS[status] ?? []
  const totalCompetitors = weights.reduce((s, w) => s + (Number(w.competitor_count) || 0), 0)
  const canCancel = !['cancelled', 'archived'].includes(status)

  /* publish checklist (client-side mirror of server validation) */
  const checklist = [
    { ok: weights.length > 0, label: `${weights.length || 'No'} weight ${weights.length === 1 ? 'class' : 'classes'}` },
    { ok: weights.length > 0 && weights.every((w) => (Number(w.competitor_count) || 0) >= 2), label: 'Every weight has wrestlers' },
    { ok: weights.length > 0 && weights.every((w) => w.status && w.status !== 'pending' ? true : (Number(w.bracket_size) || 0) > 0 || w.has_bracket), label: 'Brackets generated (server re-validates)' },
  ]

  return (
    <div>
      <PageHeader
        title={tournament?.name ?? 'Tournament'}
        sub={
          <span className="flex flex-wrap items-center gap-x-3 gap-y-1">
            <span className="font-mono">{tournament?.year}</span>
            {tournament?.location && <span>{tournament.location}</span>}
            {tournament?.locks_at > 0 && ['open', 'locked'].includes(status) && (
              <span className="inline-flex items-center gap-1.5">locks in <Countdown to={tournament.locks_at} /></span>
            )}
          </span>
        }
        actions={<StatusPill status={status} className="text-xs" />}
      />

      {/* stats */}
      <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
        {[
          { label: 'Entries', value: tournament?.entry_count ?? 0, icon: <Users size={16} /> },
          { label: 'Weights', value: weights.length, icon: <Layers size={16} /> },
          { label: 'Competitors', value: totalCompetitors, icon: <Trophy size={16} /> },
          { label: 'Locks at', value: tournament?.locks_at ? formatDateTime(tournament.locks_at) : '—', icon: <Lock size={16} />, mono: false },
        ].map((s, i) => (
          <motion.div key={s.label} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.04 }}>
            <Stat label={s.label} value={s.value} icon={s.icon} mono={s.mono !== false} className={s.mono === false ? '[&>div:nth-child(2)]:text-sm' : undefined} />
          </motion.div>
        ))}
      </div>

      {/* status actions */}
      <Card className="mb-6 p-5">
        <h2 className="mb-1 font-display text-sm uppercase tracking-wide text-ink-100">Status</h2>
        <p className="mb-4 text-sm text-ink-500">
          {status === 'draft' && 'Editable and hidden from players. Publish when the structure is solid.'}
          {status === 'open' && 'Live in the directory — players are picking right now.'}
          {status === 'locked' && 'Picks are frozen. Start the tournament when the first whistle blows.'}
          {status === 'live' && 'Results are being entered and scored in real time.'}
          {status === 'completed' && 'All done — standings are final.'}
          {status === 'archived' && 'Archived. Hidden from the directory but preserved forever.'}
          {status === 'cancelled' && 'Cancelled. Read-only.'}
        </p>
        {status === 'draft' && (
          <ul className="mb-4 grid gap-1.5 sm:grid-cols-3">
            {checklist.map((c) => (
              <li key={c.label} className={`flex items-center gap-1.5 text-xs font-semibold ${c.ok ? 'text-pin-400' : 'text-blood-400'}`}>
                {c.ok ? <CheckCircle2 size={13} /> : <XCircle size={13} />} {c.label}
              </li>
            ))}
          </ul>
        )}
        <div className="flex flex-wrap gap-2">
          {transitions.map((tr) => (
            <Button key={tr.action} variant={tr.variant} onClick={() => setPendingAction(tr)}>
              <tr.icon size={15} /> {tr.label}
            </Button>
          ))}
          {transitions.length === 0 && <span className="text-sm text-ink-600">No transitions available from {status}.</span>}
        </div>
      </Card>

      {/* sub-page cards */}
      <div className="mb-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {[
          { to: 'builder', icon: Hammer, label: 'Builder', body: 'Weights, wrestlers, templates & bracket generation.' },
          { to: 'import', icon: FileUp, label: 'PDF Import', body: 'Upload a bracket PDF and review the extraction.' },
          { to: 'results', icon: ListChecks, label: 'Results', body: 'Mat-side result entry — fast, keyboard-first.' },
          { to: 'scoring', icon: SlidersHorizontal, label: 'Scoring', body: 'Point grids, pick’em config, tiebreakers, rescore.' },
          { to: 'analytics', icon: BarChart3, label: 'Analytics', body: 'Entries funnel, pick trends, score distribution.' },
        ].map((c, i) => (
          <motion.div key={c.to} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.05 + i * 0.04 }}>
            <Link to={`/admin/tournaments/${id}/${c.to}`}>
              <Card hover className="group h-full p-5">
                <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-mat-800 text-gold-500 transition-colors group-hover:bg-gold-500 group-hover:text-mat-950">
                  <c.icon size={18} />
                </span>
                <h3 className="mt-3 font-display text-sm uppercase tracking-wide text-ink-100">{c.label}</h3>
                <p className="mt-1 text-xs text-ink-500">{c.body}</p>
              </Card>
            </Link>
          </motion.div>
        ))}
        <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.25 }}>
          <button type="button" onClick={doExport} className="block h-full w-full text-left">
            <Card hover className="group h-full p-5">
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-mat-800 text-gold-500 transition-colors group-hover:bg-gold-500 group-hover:text-mat-950">
                <Download size={18} />
              </span>
              <h3 className="mt-3 font-display text-sm uppercase tracking-wide text-ink-100">{exporting ? 'Exporting…' : 'Export'}</h3>
              <p className="mt-1 text-xs text-ink-500">Full JSON snapshot — archive, entries, matches, history.</p>
            </Card>
          </button>
        </motion.div>
      </div>

      {/* danger zone */}
      {canCancel && (
        <Card className="border-blood-500/30 p-5">
          <h2 className="mb-1 flex items-center gap-2 font-display text-sm uppercase tracking-wide text-blood-400">
            <ShieldAlert size={15} /> Danger zone
          </h2>
          <p className="mb-4 text-sm text-ink-500">
            Cancelling stops everything and is audited. Tournaments are never deleted — history is preserved.
          </p>
          <Button variant="danger" onClick={() => setCancelOpen(true)}>
            <Ban size={15} /> Cancel tournament
          </Button>
        </Card>
      )}

      {/* transition confirm */}
      <ConfirmModal
        open={!!pendingAction}
        onClose={() => setPendingAction(null)}
        title={pendingAction?.label ?? ''}
        body={
          pendingAction?.action === 'publish' ? (
            <div className="space-y-3">
              <p className="text-sm text-ink-300">{pendingAction.blurb}</p>
              <ul className="space-y-1.5">
                {checklist.map((c) => (
                  <li key={c.label} className={`flex items-center gap-1.5 text-xs font-semibold ${c.ok ? 'text-pin-400' : 'text-blood-400'}`}>
                    {c.ok ? <CheckCircle2 size={13} /> : <XCircle size={13} />} {c.label}
                  </li>
                ))}
              </ul>
              <p className="text-xs text-ink-500">The server validates again — a failed publish returns the exact problems.</p>
            </div>
          ) : (
            pendingAction?.blurb
          )
        }
        confirmLabel={pendingAction?.label}
        loading={statusMut.isPending}
        requireReason={pendingAction?.reason}
        onConfirm={(reason) => statusMut.mutate({ action: pendingAction.action, reason })}
      />

      {/* cancel confirm */}
      <ConfirmModal
        open={cancelOpen}
        onClose={() => setCancelOpen(false)}
        title="Cancel tournament"
        body={`This cancels “${tournament?.name}” for ${plural(tournament?.entry_count ?? 0, 'player', 'players')}. It cannot be undone — only audited. The tournament stays readable for history.`}
        confirmLabel="Cancel tournament"
        danger
        requireReason
        reasonPlaceholder="Why is this tournament being cancelled?"
        loading={statusMut.isPending}
        onConfirm={(reason) => statusMut.mutate({ action: 'cancel', reason })}
      />
    </div>
  )
}

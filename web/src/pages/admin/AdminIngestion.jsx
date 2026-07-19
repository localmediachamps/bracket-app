import { useEffect, useMemo, useState } from 'react'
import { useParams, useSearchParams } from 'react-router-dom'
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { AnimatePresence, motion } from 'framer-motion'
import {
  ArrowRight, Check, CheckCheck, ChevronDown, ChevronLeft, ChevronRight, Copy, GitCompare,
  ListChecks, Pencil, Plus, Radio, Satellite, SquarePen, Terminal, Trash2, X,
} from 'lucide-react'
import { api, XANO_ADMIN } from '../../lib/api'
import { toast } from '../../lib/store'
import {
  Badge, Button, Card, EmptyState, Input, Modal, Select, Skeleton, Switch, Tabs, Textarea,
} from '../../components/ui'
import { cn, formatDateTime, VICTORY_TYPES, victoryLabel } from '../../lib/utils'
import { ConfirmModal, ErrorState, PageHeader } from '../../components/admin/AdminCommon'
import { errMsg, timeAgo } from '../../components/admin/adminUtils'

const PER = 25
const README_URL = 'https://github.com/localmediachamps/bracket-app/blob/HEAD/scripts/trackwrestling/README.md'

const STATUS_FILTERS = [
  { key: 'needs_review', label: 'Needs review' },
  { key: 'matched', label: 'Matched' },
  { key: 'conflict', label: 'Conflict' },
  { key: 'approved', label: 'Approved' },
  { key: 'rejected', label: 'Rejected' },
  { key: 'all', label: 'All' },
]

const EMPTY_COPY = {
  needs_review: ['Queue is clear', 'New candidates from your sources will land here for a human decision.'],
  matched: ['No matched candidates', 'High-confidence matches ready for one-click approval will show up here.'],
  conflict: ['No conflicting candidates', 'Nothing is currently disagreeing with the official record.'],
  approved: ['Nothing approved yet', 'Approved candidates become official results and rescore the tournament.'],
  rejected: ['Nothing rejected', 'Rejected candidates are kept around for audit.'],
  all: ['No candidates yet', 'Run the scraper for one of your sources to pull external results in.'],
}

const TERMINAL_STATUSES = new Set(['approved', 'auto_approved', 'rejected', 'superseded', 'failed'])

const listVariants = { hidden: {}, show: { transition: { staggerChildren: 0.05 } } }
const itemVariants = { hidden: { opacity: 0, y: 10 }, show: { opacity: 1, y: 0, transition: { duration: 0.22 } } }

const fmtConf = (v) => (v === null || v === undefined || isNaN(+v) ? '—' : (+v).toFixed(2))

/** Invalidate every ingestion query for a tournament after a mutation. */
function useInvalidateIngestion(tournamentId) {
  const qc = useQueryClient()
  return () => {
    qc.invalidateQueries({ queryKey: ['admin-sources', tournamentId] })
    qc.invalidateQueries({ queryKey: ['admin-candidates', tournamentId] })
    qc.invalidateQueries({ queryKey: ['admin-conflicts', tournamentId] })
  }
}

/* ── Page ─────────────────────────────────────────────── */
export default function AdminIngestion() {
  const { id } = useParams()
  const [searchParams, setSearchParams] = useSearchParams()
  const tab = searchParams.get('tab') || 'sources'
  const setTab = (key) => {
    const p = new URLSearchParams(searchParams)
    p.set('tab', key)
    setSearchParams(p, { replace: true })
  }

  /* fetched at page level — drives tab badge counts and the tabs themselves */
  const sourcesQ = useQuery({ queryKey: ['admin-sources', id], queryFn: () => api.adminSources(id) })
  const conflictsQ = useQuery({ queryKey: ['admin-conflicts', id], queryFn: () => api.adminConflicts(id, { status: 'open' }) })

  const sources = useMemo(() => sourcesQ.data?.items ?? (Array.isArray(sourcesQ.data) ? sourcesQ.data : []), [sourcesQ.data])

  /* aggregate candidate status buckets across sources → filter-chip counts */
  const counts = useMemo(() => {
    const agg = { needs_review: 0, matched: 0, conflict: 0, approved: 0, rejected: 0, all: 0 }
    for (const s of sources) {
      const c = s.candidate_counts ?? {}
      agg.needs_review += c.needs_review ?? 0
      agg.matched += c.matched ?? 0
      agg.conflict += c.conflict ?? 0
      agg.approved += c.approved ?? 0
      agg.rejected += c.rejected ?? 0
      agg.all += (c.detected ?? 0) + (c.needs_review ?? 0) + (c.matched ?? 0) + (c.approved ?? 0) + (c.rejected ?? 0) + (c.conflict ?? 0) + (c.failed ?? 0)
    }
    return agg
  }, [sources])

  const openConflicts = conflictsQ.data?.total ?? conflictsQ.data?.items?.length

  const tabs = [
    { key: 'sources', label: 'Sources', icon: <Radio size={15} />, count: sourcesQ.data ? sources.length : undefined },
    { key: 'review', label: 'Review queue', icon: <ListChecks size={15} />, count: sourcesQ.data ? counts.needs_review : undefined },
    { key: 'conflicts', label: 'Conflicts', icon: <GitCompare size={15} />, count: conflictsQ.data ? openConflicts : undefined },
  ]

  return (
    <div className="pb-8">
      <PageHeader title="Results Ingestion" sub="External sources → review → official results" />
      <Tabs className="mb-5" tabs={tabs} active={tab} onChange={setTab} />
      {tab === 'sources' && <SourcesTab tournamentId={id} q={sourcesQ} />}
      {tab === 'review' && <ReviewTab tournamentId={id} counts={counts} countsReady={!!sourcesQ.data} />}
      {tab === 'conflicts' && <ConflictsTab q={conflictsQ} onGoReview={() => setTab('review')} />}
    </div>
  )
}

/* ══ Tab 1: Sources ═════════════════════════════════════ */
function SourcesTab({ tournamentId, q }) {
  const invalidate = useInvalidateIngestion(tournamentId)
  const [adding, setAdding] = useState(false)
  const [editing, setEditing] = useState(null)
  const [deleting, setDeleting] = useState(null)

  const deleteMut = useMutation({
    mutationFn: (sourceId) => api.adminDeleteSource(sourceId),
    onSuccess: () => {
      toast.success('Source deleted')
      setDeleting(null)
      invalidate()
    },
    onError: (e) => toast.error('Delete failed', { body: errMsg(e) }),
  })

  const items = q.data?.items ?? (Array.isArray(q.data) ? q.data : [])

  if (q.isLoading) {
    return (
      <div className="space-y-3">
        <Skeleton className="h-32" />
        <Skeleton className="h-32" />
        <Skeleton className="h-32" />
      </div>
    )
  }
  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} title="Couldn't load sources" />

  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <p className="text-xs text-ink-500">
          {items.length} source{items.length === 1 ? '' : 's'} feeding this tournament
        </p>
        <Button variant="primary" size="sm" onClick={() => setAdding(true)}>
          <Plus size={14} /> Add source
        </Button>
      </div>

      {items.length === 0 ? (
        <EmptyState
          icon={<Satellite size={24} />}
          title="No sources configured"
          body="Point a source (TrackWrestling event, manual upload, …) at this tournament and results start flowing into the review queue."
          action={
            <Button variant="primary" size="sm" onClick={() => setAdding(true)}>
              <Plus size={14} /> Add your first source
            </Button>
          }
        />
      ) : (
        <motion.div variants={listVariants} initial="hidden" animate="show" className="space-y-3">
          {items.map((s) => (
            <motion.div key={s.id} variants={itemVariants}>
              <SourceCard source={s} onEdit={() => setEditing(s)} onDelete={() => setDeleting(s)} />
            </motion.div>
          ))}
        </motion.div>
      )}

      <SourceFormModal key="create" tournamentId={tournamentId} open={adding} onClose={() => setAdding(false)} />
      <SourceFormModal key={editing?.id ?? 'edit'} tournamentId={tournamentId} source={editing} open={!!editing} onClose={() => setEditing(null)} />

      <ConfirmModal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        title="Delete source"
        body={
          deleting && (
            <span>
              Deletes <strong>{deleting.name}</strong> and stops future ingests from it. Candidates already in the queue are kept.
            </span>
          )
        }
        confirmLabel="Delete source"
        danger
        loading={deleteMut.isPending}
        onConfirm={() => deleteMut.mutate(deleting.id)}
      />
    </div>
  )
}

/* ── One source config card ───────────────────────────── */
function SourceCard({ source: s, onEdit, onDelete }) {
  const [cheat, setCheat] = useState(false)
  const counts = s.candidate_counts ?? {}
  return (
    <Card className="p-4 sm:p-5">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-1.5">
            <h3 className="text-sm font-bold text-ink-100">{s.name}</h3>
            <Badge color="ink">{s.source_type ?? 'trackwrestling'}</Badge>
            <PolicyPill policy={s.approval_policy} threshold={s.auto_approve_threshold} />
            <HealthPill status={s.health_status} enabled={s.enabled} />
          </div>
          <p className="mt-1.5 text-xs text-ink-500">
            Last checked <span title={formatDateTime(s.last_checked_at)}>{timeAgo(s.last_checked_at)}</span>
            {s.last_error ? <span className="text-blood-400"> · {s.last_error}</span> : null}
          </p>
          <div className="mt-3 flex flex-wrap gap-1.5">
            <StatChip tone="gold" value={counts.needs_review} label="needs review" />
            <StatChip tone="pin" value={counts.matched} label="matched" />
            <StatChip tone="blood" value={counts.conflict} label="conflict" />
          </div>
        </div>
        <div className="flex shrink-0 gap-1">
          <IconBtn label="Scraper cheat sheet" active={cheat} onClick={() => setCheat((v) => !v)}>
            <Terminal size={14} />
          </IconBtn>
          <IconBtn label={`Edit source ${s.name}`} onClick={onEdit}>
            <Pencil size={14} />
          </IconBtn>
          <IconBtn label={`Delete source ${s.name}`} danger onClick={onDelete}>
            <Trash2 size={14} />
          </IconBtn>
        </div>
      </div>
      <AnimatePresence>{cheat && <ScraperCheatsheet source={s} />}</AnimatePresence>
    </Card>
  )
}

function PolicyPill({ policy, threshold }) {
  if (policy === 'auto_high_confidence') return <Badge color="pin">{`Auto ≥${threshold ?? 0.9}`}</Badge>
  if (policy === 'auto_all') return <Badge color="blood">Auto all</Badge>
  return <Badge color="gold">Review</Badge>
}

function HealthPill({ status, enabled }) {
  if (enabled === false || status === 'disabled') return <Badge color="ink">Disabled</Badge>
  const tones = { healthy: 'pin', degraded: 'gold', failing: 'blood' }
  return <Badge color={tones[status] ?? 'ink'}>{status ?? 'unknown'}</Badge>
}

function StatChip({ tone, value, label }) {
  const tones = {
    gold: 'border-gold-500/30 bg-gold-500/10 text-gold-400',
    pin: 'border-pin-500/30 bg-pin-500/10 text-pin-400',
    blood: 'border-blood-500/30 bg-blood-500/10 text-blood-400',
  }
  return (
    <span className={cn('inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider', tones[tone])}>
      <span className="font-mono">{value ?? 0}</span>
      {label}
    </span>
  )
}

function IconBtn({ label, onClick, danger, active, children }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      aria-pressed={!!active}
      className={cn(
        'rounded-lg p-2 transition-colors',
        danger
          ? 'text-ink-500 hover:bg-blood-500/15 hover:text-blood-400'
          : active
            ? 'bg-mat-700 text-gold-400'
            : 'text-ink-500 hover:bg-mat-700 hover:text-gold-400'
      )}
    >
      {children}
    </button>
  )
}

/* ── Collapsible scraper cheat sheet ──────────────────── */
function ScraperCheatsheet({ source }) {
  const cfg = source.configuration ?? {}
  const cmd = [
    'python scripts/trackwrestling/tw.py run',
    `--season ${cfg.season_id ?? '<season_id>'}`,
    `--event ${cfg.event_id ?? '<event_id>'}`,
    `--source-config ${source.id}`,
    `--api-base ${XANO_ADMIN}`,
    '--token <admin-token>',
  ].join(' ')
  return (
    <motion.div
      initial={{ height: 0, opacity: 0 }}
      animate={{ height: 'auto', opacity: 1 }}
      exit={{ height: 0, opacity: 0 }}
      transition={{ duration: 0.18 }}
      className="overflow-hidden"
    >
      <div className="mt-4 rounded-lg border border-mat-700 bg-mat-900/60 p-3.5">
        <div className="mb-2 flex items-center justify-between gap-2">
          <p className="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-wider text-ink-500">
            <Terminal size={12} /> Run the scraper
          </p>
          <CopyButton text={cmd} />
        </div>
        <pre className="overflow-x-auto whitespace-pre-wrap break-all rounded-md bg-mat-950/70 p-2.5 font-mono text-[11px] leading-relaxed text-gold-300">
          {cmd}
        </pre>
        <p className="mt-2 text-[11px] leading-relaxed text-ink-500">
          <code className="rounded bg-mat-800 px-1 font-mono text-[10px] text-ink-300">{'<admin-token>'}</code> is your login token —
          the same bearer token this app uses after you sign in. Full scraper docs in{' '}
          <a
            href={README_URL}
            target="_blank"
            rel="noreferrer"
            className="font-semibold text-gold-400 underline decoration-gold-500/40 underline-offset-2 hover:text-gold-300"
          >
            scripts/trackwrestling/README.md
          </a>
          .
        </p>
      </div>
    </motion.div>
  )
}

function CopyButton({ text, label = 'Copy' }) {
  const [copied, setCopied] = useState(false)
  const doCopy = async () => {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      setTimeout(() => setCopied(false), 1600)
    } catch {
      toast.error('Copy failed', { body: 'Clipboard is unavailable in this browser.' })
    }
  }
  return (
    <Button variant="secondary" size="xs" onClick={doCopy}>
      {copied ? <Check size={12} /> : <Copy size={12} />} {copied ? 'Copied' : label}
    </Button>
  )
}

/* ── Create / edit source modal ───────────────────────── */
function SourceFormModal({ tournamentId, source, open, onClose }) {
  const invalidate = useInvalidateIngestion(tournamentId)
  const editing = !!source
  const [name, setName] = useState('')
  const [policy, setPolicy] = useState('review')
  const [threshold, setThreshold] = useState('0.9')
  const [seasonId, setSeasonId] = useState('')
  const [eventId, setEventId] = useState('')
  const [externalId, setExternalId] = useState('')
  const [enabled, setEnabled] = useState(true)
  const [threshErr, setThreshErr] = useState('')

  useEffect(() => {
    if (!open) return
    setName(source?.name ?? '')
    setPolicy(source?.approval_policy ?? 'review')
    setThreshold(String(source?.auto_approve_threshold ?? '0.9'))
    setSeasonId(source?.configuration?.season_id ?? '')
    setEventId(source?.configuration?.event_id ?? '')
    setExternalId(source?.configuration?.tournament_id_external ?? '')
    setEnabled(source?.enabled ?? true)
    setThreshErr('')
  }, [open, source])

  const mut = useMutation({
    mutationFn: (payload) => (editing ? api.adminUpdateSource(source.id, payload) : api.adminCreateSource(tournamentId, payload)),
    onSuccess: () => {
      toast.success(editing ? 'Source updated' : 'Source added')
      invalidate()
      onClose()
    },
    onError: (e) => toast.error('Save failed', { body: errMsg(e) }),
  })

  const submit = (e) => {
    e.preventDefault()
    const configuration = {}
    if (seasonId.trim()) configuration.season_id = seasonId.trim()
    if (eventId.trim()) configuration.event_id = eventId.trim()
    if (externalId.trim()) configuration.tournament_id_external = externalId.trim()
    const payload = { name: name.trim(), source_type: 'trackwrestling', approval_policy: policy, configuration }
    if (policy === 'auto_high_confidence') {
      const t = parseFloat(threshold)
      if (isNaN(t) || t < 0 || t > 1) {
        setThreshErr('Enter a value between 0 and 1')
        return
      }
      payload.auto_approve_threshold = t
    }
    if (editing) payload.enabled = enabled
    mut.mutate(payload)
  }

  return (
    <Modal open={open} onClose={mut.isPending ? undefined : onClose} title={editing ? 'Edit source' : 'Add source'}>
      <form onSubmit={submit} className="space-y-4">
        <Input label="Name" value={name} onChange={(e) => setName(e.target.value)} placeholder="TrackWrestling — 2026 NCAA DI" required autoFocus />
        <div>
          <Select label="Source adapter" value="trackwrestling" onChange={() => {}} disabled className="opacity-70">
            <option value="trackwrestling">TrackWrestling</option>
          </Select>
          <p className="mt-1 text-[11px] text-ink-600">TrackWrestling is the only wired adapter right now.</p>
        </div>
        <Select label="Approval policy" value={policy} onChange={(e) => setPolicy(e.target.value)}>
          <option value="review">Review — every candidate hits the queue</option>
          <option value="auto_high_confidence">Auto ≥ threshold — confident matches apply themselves</option>
          <option value="auto_all">Auto all — everything applies (dangerous)</option>
        </Select>
        {policy === 'auto_high_confidence' && (
          <Input
            label="Auto-approve threshold (0–1)"
            type="number"
            min="0"
            max="1"
            step="0.01"
            value={threshold}
            onChange={(e) => {
              setThreshold(e.target.value)
              setThreshErr('')
            }}
            error={threshErr || undefined}
          />
        )}
        <div className="grid gap-3 sm:grid-cols-3">
          <Input label="Season ID" value={seasonId} onChange={(e) => setSeasonId(e.target.value)} placeholder="1560238138" />
          <Input label="Event ID" value={eventId} onChange={(e) => setEventId(e.target.value)} placeholder="8710102132" />
          <Input label="External tournament ID" value={externalId} onChange={(e) => setExternalId(e.target.value)} placeholder="optional" />
        </div>
        {editing && (
          <Switch checked={enabled} onChange={setEnabled} label="Enabled" description="Disabled sources are skipped by the scraper and report as disabled." />
        )}
        <div className="flex justify-end gap-2">
          <Button variant="ghost" type="button" onClick={onClose} disabled={mut.isPending}>
            Cancel
          </Button>
          <Button variant="primary" type="submit" disabled={!name.trim()} loading={mut.isPending}>
            <Check size={15} /> {editing ? 'Save changes' : 'Add source'}
          </Button>
        </div>
      </form>
    </Modal>
  )
}

/* ══ Tab 2: Review queue ════════════════════════════════ */
function ReviewTab({ tournamentId, counts, countsReady }) {
  const invalidate = useInvalidateIngestion(tournamentId)
  const [status, setStatus] = useState('needs_review')
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState(() => new Set())
  const [editCandidate, setEditCandidate] = useState(null)
  const [rejectCandidate, setRejectCandidate] = useState(null)

  const q = useQuery({
    queryKey: ['admin-candidates', tournamentId, status, page],
    queryFn: () => api.adminCandidates(tournamentId, { status: status === 'all' ? undefined : status, page, per: PER }),
    placeholderData: keepPreviousData,
  })

  const items = q.data?.items ?? []
  const total = q.data?.total ?? 0
  const pages = Math.max(1, Math.ceil(total / PER))

  const changeStatus = (s) => {
    setStatus(s)
    setPage(1)
    setSelected(new Set())
  }

  const toggleSelect = (cand) => {
    if (cand.status !== 'matched') return
    setSelected((s) => {
      const n = new Set(s)
      if (n.has(cand.id)) n.delete(cand.id)
      else n.add(cand.id)
      return n
    })
  }

  const approveMut = useMutation({
    mutationFn: (candidateId) => api.adminApproveCandidate(candidateId),
    onSuccess: () => {
      toast.success('Result applied', { body: 'Candidate approved and tournament rescored.' })
      invalidate()
    },
    onError: (e) => toast.error('Approve failed', { body: errMsg(e) }),
  })

  const bulkMut = useMutation({
    mutationFn: (ids) => api.adminBulkApproveCandidates(tournamentId, ids),
    onSuccess: (d) => {
      const applied = d?.applied ?? 0
      const failed = d?.failed?.length ?? 0
      if (applied > 0) {
        toast.success(`Bulk approve: ${applied} applied`, { body: failed ? `${failed} failed — review those individually.` : 'Tournament rescored.' })
      } else {
        toast.error('Bulk approve applied nothing', { body: failed ? `${failed} failed — review those individually.` : undefined })
      }
      setSelected(new Set())
      invalidate()
    },
    onError: (e) => toast.error('Bulk approve failed', { body: errMsg(e) }),
  })

  const [emptyTitle, emptyBody] = EMPTY_COPY[status] ?? EMPTY_COPY.all

  return (
    <div>
      {/* status filter chips */}
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-1 rounded-lg border border-mat-700 bg-mat-850 p-1" role="tablist" aria-label="Candidate status filter">
          {STATUS_FILTERS.map((f) => (
            <button
              key={f.key}
              role="tab"
              aria-selected={status === f.key}
              onClick={() => changeStatus(f.key)}
              className={cn(
                'rounded-md px-3 py-1.5 text-xs font-bold transition-colors',
                status === f.key ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200'
              )}
            >
              {f.label}
              {countsReady && (
                <span className="ml-1.5 font-mono text-[10px] font-normal text-ink-600">{counts[f.key] ?? 0}</span>
              )}
            </button>
          ))}
        </div>
        <span className="text-xs text-ink-500">
          <span className="font-mono font-bold text-ink-300">{total}</span> candidate{total === 1 ? '' : 's'}
        </span>
      </div>

      {/* bulk bar */}
      <AnimatePresence>
        {selected.size > 0 && (
          <motion.div
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -6 }}
            className="sticky top-2 z-20 mb-3"
          >
            <Card className="flex flex-wrap items-center gap-3 border-pin-500/40 bg-mat-850/95 px-4 py-2.5 backdrop-blur">
              <span className="text-xs font-bold text-ink-200">{selected.size} selected</span>
              <span className="hidden text-[11px] text-ink-500 sm:inline">Only matched candidates can be bulk-approved.</span>
              <div className="ml-auto flex gap-2">
                <Button variant="ghost" size="sm" onClick={() => setSelected(new Set())}>
                  Clear
                </Button>
                <Button variant="success" size="sm" loading={bulkMut.isPending} onClick={() => bulkMut.mutate([...selected])}>
                  <CheckCheck size={14} /> Approve {selected.size} selected
                </Button>
              </div>
            </Card>
          </motion.div>
        )}
      </AnimatePresence>

      {q.isLoading ? (
        <div className="space-y-3">
          <Skeleton className="h-28" />
          <Skeleton className="h-28" />
          <Skeleton className="h-28" />
          <Skeleton className="h-28" />
        </div>
      ) : q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} title="Couldn't load candidates" />
      ) : items.length === 0 ? (
        <EmptyState icon={<Satellite size={24} />} title={emptyTitle} body={emptyBody} />
      ) : (
        <>
          <motion.div variants={listVariants} initial="hidden" animate="show" className="space-y-3">
            {items.map((c) => (
              <motion.div key={c.id} variants={itemVariants}>
                <CandidateCard
                  candidate={c}
                  selected={selected.has(c.id)}
                  onToggleSelect={() => toggleSelect(c)}
                  onApprove={() => approveMut.mutate(c.id)}
                  approving={approveMut.isPending && approveMut.variables === c.id}
                  onEdit={() => setEditCandidate(c)}
                  onReject={() => setRejectCandidate(c)}
                />
              </motion.div>
            ))}
          </motion.div>

          {pages > 1 && (
            <div className="mt-4 flex items-center justify-center gap-3">
              <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
                <ChevronLeft size={14} /> Prev
              </Button>
              <span className="font-mono text-xs text-ink-400">
                Page {page} of {pages}
              </span>
              <Button variant="secondary" size="sm" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>
                Next <ChevronRight size={14} />
              </Button>
            </div>
          )}
        </>
      )}

      <ApproveEditModal candidate={editCandidate} tournamentId={tournamentId} onClose={() => setEditCandidate(null)} />
      <RejectCandidateModal candidate={rejectCandidate} tournamentId={tournamentId} onClose={() => setRejectCandidate(null)} />
    </div>
  )
}

/* ── One candidate card ───────────────────────────────── */
function CandidateCard({ candidate: c, selected, onToggleSelect, onApprove, approving, onEdit, onReject }) {
  const [rawOpen, setRawOpen] = useState(false)
  const terminal = TERMINAL_STATUSES.has(c.status)
  const selectable = c.status === 'matched'
  const victory = [victoryLabel(c.source_victory_type), c.source_score].filter(Boolean).join(' ')

  return (
    <Card className={cn('p-4 transition-colors', selected && 'border-pin-500/50')}>
      <div className="flex items-start gap-3">
        <input
          type="checkbox"
          checked={selected}
          disabled={!selectable}
          onChange={onToggleSelect}
          aria-label={`Select candidate ${c.id} for bulk approve`}
          title={selectable ? 'Select for bulk approve' : 'Only matched candidates can be bulk-approved'}
          className="mt-1 h-4 w-4 shrink-0 accent-pin-500 disabled:opacity-30"
        />
        <div className="min-w-0 flex-1">
          {/* winner def. loser */}
          <p className="text-sm leading-snug">
            <span className="font-semibold text-pin-300">{c.source_winner ?? '—'}</span>
            {c.source_winner_school && <span className="text-ink-500"> ({c.source_winner_school})</span>}
            <span className="mx-1.5 text-[11px] font-bold uppercase text-ink-600">def.</span>
            <span className="font-semibold text-ink-200">{c.source_loser ?? '—'}</span>
            {c.source_loser_school && <span className="text-ink-500"> ({c.source_loser_school})</span>}
          </p>

          {/* meta badges */}
          <div className="mt-2 flex flex-wrap items-center gap-1.5">
            <CandidateStatusPill status={c.status} />
            {c.source_weight_class && <Badge color="ink">{c.source_weight_class}</Badge>}
            {c.source_round && <Badge color="ink">{c.source_round}</Badge>}
            {victory && (
              <span className="rounded bg-mat-700 px-2 py-0.5 font-mono text-[11px] font-bold text-pin-400">{victory}</span>
            )}
            {c.source_name && <span className="text-[11px] text-ink-600">via {c.source_name}</span>}
            <span className="text-[11px] text-ink-600" title={formatDateTime(c.created_at)}>
              {timeAgo(c.created_at)}
            </span>
          </div>

          {/* matched match brief */}
          {c.match && (
            <p className="mt-1.5 flex flex-wrap items-center gap-1.5 text-xs text-ink-500">
              <GitCompare size={12} className="shrink-0 text-pin-400" />
              <span className="font-semibold text-ink-300">
                {c.match.round_label} #{c.match.match_number}
              </span>
              {c.match.weight ? <span>· {c.match.weight} lbs</span> : null}
              <span className="truncate">
                — {c.match.top_participant ?? '?'} vs {c.match.bottom_participant ?? '?'}
              </span>
            </p>
          )}

          <ConfidenceBlock candidate={c} />

          {/* raw fragment */}
          {c.raw_fragment && (
            <div className="mt-2">
              <button
                type="button"
                onClick={() => setRawOpen((v) => !v)}
                aria-expanded={rawOpen}
                className="flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider text-ink-600 transition-colors hover:text-ink-300"
              >
                <ChevronDown size={12} className={cn('transition-transform', rawOpen && 'rotate-180')} />
                Raw fragment
              </button>
              {rawOpen && (
                <pre className="mt-1.5 max-h-40 overflow-auto whitespace-pre-wrap break-all rounded-md bg-mat-900/70 p-2 font-mono text-[10px] leading-relaxed text-ink-400">
                  {c.raw_fragment}
                </pre>
              )}
            </div>
          )}

          {/* actions */}
          {!terminal && (
            <div className="mt-3 flex flex-wrap justify-end gap-1.5">
              <Button variant="success" size="sm" onClick={onApprove} loading={approving}>
                <Check size={14} /> Approve
              </Button>
              <Button variant="secondary" size="sm" onClick={onEdit}>
                <SquarePen size={13} /> Approve w/ edit
              </Button>
              <Button variant="danger" size="sm" onClick={onReject}>
                <X size={14} /> Reject
              </Button>
            </div>
          )}
        </div>
      </div>
    </Card>
  )
}

const CANDIDATE_TONES = {
  needs_review: 'gold',
  matched: 'pin',
  conflict: 'blood',
  approved: 'pin',
  auto_approved: 'pin',
  rejected: 'ink',
  failed: 'blood',
}

function CandidateStatusPill({ status }) {
  return <Badge color={CANDIDATE_TONES[status] ?? 'ink'}>{String(status ?? 'unknown').replace(/_/g, ' ')}</Badge>
}

/* confidence bar with hover-expanding sub-scores */
function ConfidenceBlock({ candidate: c }) {
  const v = c.overall_confidence
  const num = v === null || v === undefined || isNaN(+v) ? null : +v
  const tier = num === null ? 'none' : num >= 0.9 ? 'gold' : num >= 0.6 ? 'ink' : 'blood'
  const gradients = {
    gold: 'from-gold-600 via-gold-500 to-gold-400',
    ink: 'from-ink-600 to-ink-400',
    blood: 'from-blood-600 to-blood-400',
  }
  const textTone = tier === 'gold' ? 'text-gold-400' : tier === 'blood' ? 'text-blood-400' : 'text-ink-300'
  return (
    <div className="group mt-3 max-w-md" tabIndex={0}>
      <div className="flex items-center gap-2">
        <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-mat-700" role="progressbar" aria-valuenow={num === null ? 0 : Math.round(num * 100)} aria-valuemin={0} aria-valuemax={100}>
          {num !== null && (
            <div className={cn('h-full rounded-full bg-gradient-to-r', gradients[tier])} style={{ width: `${Math.min(100, Math.max(0, num * 100))}%` }} />
          )}
        </div>
        <span className={cn('font-mono text-[11px] font-bold', textTone)}>{fmtConf(v)}</span>
      </div>
      <div className="max-h-0 overflow-hidden opacity-0 transition-all duration-200 group-focus-within:max-h-8 group-focus-within:opacity-100 group-hover:max-h-8 group-hover:opacity-100">
        <div className="flex gap-3 pt-1.5 font-mono text-[10px] text-ink-500">
          <span>extraction {fmtConf(c.extraction_confidence)}</span>
          <span>identity {fmtConf(c.identity_confidence)}</span>
          <span>match {fmtConf(c.match_confidence)}</span>
        </div>
      </div>
    </div>
  )
}

/* ── Approve with edits modal ─────────────────────────── */
function ApproveEditModal({ candidate, tournamentId, onClose }) {
  const invalidate = useInvalidateIngestion(tournamentId)
  const [winnerId, setWinnerId] = useState('')
  const [victory, setVictory] = useState('decision')
  const [score, setScore] = useState('')

  useEffect(() => {
    if (!candidate) return
    const p = candidate.normalized_payload ?? {}
    setWinnerId(String(p.winner_competitor_id ?? p.loser_competitor_id ?? ''))
    setVictory(VICTORY_TYPES[p.victory_type] ? p.victory_type : 'decision')
    setScore(p.score ?? candidate.source_score ?? '')
  }, [candidate])

  const mut = useMutation({
    mutationFn: () => {
      const override = { victory_type: victory }
      if (winnerId) override.winner_competitor_id = Number(winnerId)
      if (score.trim()) override.score = score.trim()
      return api.adminApproveCandidate(candidate.id, override)
    },
    onSuccess: () => {
      toast.success('Result applied with edits', { body: 'Candidate approved and tournament rescored.' })
      invalidate()
      onClose()
    },
    onError: (e) => toast.error('Approve failed', { body: errMsg(e) }),
  })

  const np = candidate?.normalized_payload ?? {}
  const options = []
  if (np.winner_competitor_id != null) {
    options.push({
      value: String(np.winner_competitor_id),
      label: `${candidate?.source_winner ?? 'Parsed winner'}${candidate?.source_winner_school ? ` (${candidate.source_winner_school})` : ''}`,
    })
  }
  if (np.loser_competitor_id != null) {
    options.push({
      value: String(np.loser_competitor_id),
      label: `${candidate?.source_loser ?? 'Parsed loser'}${candidate?.source_loser_school ? ` (${candidate.source_loser_school})` : ''}`,
    })
  }

  return (
    <Modal open={!!candidate} onClose={mut.isPending ? undefined : onClose} title="Approve with edits">
      <form
        onSubmit={(e) => {
          e.preventDefault()
          mut.mutate()
        }}
        className="space-y-4"
      >
        {candidate && (
          <p className="text-sm text-ink-300">
            <strong className="text-pin-300">{candidate.source_winner}</strong>
            <span className="mx-1.5 text-[11px] font-bold uppercase text-ink-600">def.</span>
            <strong>{candidate.source_loser}</strong>
          </p>
        )}
        {options.length > 0 ? (
          <Select label="Winner" value={winnerId} onChange={(e) => setWinnerId(e.target.value)}>
            {options.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </Select>
        ) : (
          <p className="rounded-lg border border-mat-700 bg-mat-800 px-3 py-2 text-xs text-ink-500">
            No resolved competitor ids on this candidate — only victory type and score edits will be sent.
          </p>
        )}
        <Select label="Victory type" value={victory} onChange={(e) => setVictory(e.target.value)}>
          {Object.entries(VICTORY_TYPES).map(([key, v]) => (
            <option key={key} value={key}>
              {v.label} — {v.name}
            </option>
          ))}
        </Select>
        <Input label="Score" value={score} onChange={(e) => setScore(e.target.value)} placeholder="7-2" />
        <div className="flex justify-end gap-2">
          <Button variant="ghost" type="button" onClick={onClose} disabled={mut.isPending}>
            Cancel
          </Button>
          <Button variant="success" type="submit" loading={mut.isPending}>
            <Check size={14} /> Approve & apply
          </Button>
        </div>
      </form>
    </Modal>
  )
}

/* ── Reject modal (optional reason) ───────────────────── */
function RejectCandidateModal({ candidate, tournamentId, onClose }) {
  const invalidate = useInvalidateIngestion(tournamentId)
  const [reason, setReason] = useState('')

  useEffect(() => {
    if (candidate) setReason('')
  }, [candidate])

  const mut = useMutation({
    mutationFn: () => api.adminRejectCandidate(candidate.id, reason.trim() || undefined),
    onSuccess: () => {
      toast.success('Candidate rejected')
      invalidate()
      onClose()
    },
    onError: (e) => toast.error('Reject failed', { body: errMsg(e) }),
  })

  return (
    <Modal open={!!candidate} onClose={mut.isPending ? undefined : onClose} title="Reject candidate">
      <div className="space-y-4">
        <p className="text-sm text-ink-300">
          Reject{' '}
          <strong>
            {candidate?.source_winner} def. {candidate?.source_loser}
          </strong>
          ? It stays out of the official record.
        </p>
        <Textarea rows={2} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Reason (optional)…" aria-label="Rejection reason" />
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose} disabled={mut.isPending}>
            Cancel
          </Button>
          <Button variant="danger" loading={mut.isPending} onClick={() => mut.mutate()}>
            <X size={14} /> Reject candidate
          </Button>
        </div>
      </div>
    </Modal>
  )
}

/* ══ Tab 3: Conflicts ═══════════════════════════════════ */
function ConflictsTab({ q, onGoReview }) {
  const items = q.data?.items ?? []

  if (q.isLoading) {
    return (
      <div className="space-y-3">
        <Skeleton className="h-40" />
        <Skeleton className="h-40" />
      </div>
    )
  }
  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} title="Couldn't load conflicts" />
  if (items.length === 0) {
    return (
      <EmptyState
        icon={<Satellite size={24} />}
        title="No open conflicts"
        body="When an incoming result disagrees with the official record it lands here for a side-by-side call."
      />
    )
  }

  return (
    <motion.div variants={listVariants} initial="hidden" animate="show" className="space-y-3">
      {items.map((c) => (
        <motion.div key={c.id} variants={itemVariants}>
          <ConflictCard conflict={c} onGoReview={onGoReview} />
        </motion.div>
      ))}
    </motion.div>
  )
}

function ConflictCard({ conflict: c, onGoReview }) {
  return (
    <Card className="p-4 sm:p-5">
      <div className="flex flex-wrap items-center gap-2">
        <Badge color={c.conflict_type === 'duplicate' ? 'gold' : 'blood'}>
          {String(c.conflict_type ?? 'conflict').replace(/_/g, ' ')}
        </Badge>
        {c.match && (
          <span className="text-xs font-semibold text-ink-300">
            {c.match.round_label} #{c.match.match_number}
          </span>
        )}
        <span className="text-[11px] text-ink-600" title={formatDateTime(c.created_at)}>
          {timeAgo(c.created_at)}
        </span>
        <Button variant="secondary" size="xs" className="ml-auto" onClick={onGoReview}>
          Go to review <ArrowRight size={12} />
        </Button>
      </div>

      {c.candidate && (
        <p className="mt-2 text-xs text-ink-500">
          Candidate <span className="font-mono text-ink-300">#{c.candidate.id}</span>
          {' · '}
          {c.candidate.source_winner ?? '?'} def. {c.candidate.source_loser ?? '?'}
          {c.candidate.source_weight_class ? ` · ${c.candidate.source_weight_class}` : ''}
          {c.candidate.overall_confidence != null ? ` · conf ${fmtConf(c.candidate.overall_confidence)}` : ''}
          {' — find it in the review queue to act on it.'}
        </p>
      )}

      <div className="mt-3 grid gap-3 lg:grid-cols-2">
        <JsonPane title="Existing (official)" value={c.existing_value} tone="pin" />
        <JsonPane title="Candidate (incoming)" value={c.candidate_value} tone="gold" />
      </div>
    </Card>
  )
}

function JsonPane({ title, value, tone }) {
  const pretty = value === null || value === undefined ? '—' : typeof value === 'string' ? value : JSON.stringify(value, null, 2)
  const pin = tone === 'pin'
  return (
    <div className={cn('overflow-hidden rounded-lg border', pin ? 'border-pin-500/40' : 'border-gold-500/40')}>
      <p
        className={cn(
          'border-b px-3 py-1.5 text-[10px] font-bold uppercase tracking-wider',
          pin ? 'border-pin-500/30 text-pin-400' : 'border-gold-500/30 text-gold-400'
        )}
      >
        {title}
      </p>
      <pre className="max-h-64 overflow-auto bg-mat-900/50 p-3 font-mono text-[11px] leading-relaxed text-ink-300">{pretty}</pre>
    </div>
  )
}

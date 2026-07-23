import React, { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { ArrowLeft, ArrowRightLeft, Check, Plus, Repeat, X } from 'lucide-react'
import { api } from '../lib/api'
import { toast, useAuthStore } from '../lib/store'
import { Badge, Button, Card, Modal, Select, Skeleton } from '../components/ui'
import CompetitionCard from '../components/wrestlers/CompetitionCard'

const WEIGHTS = ['125', '133', '141', '149', '157', '165', '174', '184', '197', '285']

function RosterPicker({ roster, selected, onToggle, weightFilter, onWeightFilterChange }) {
  const filtered = (roster ?? []).filter((r) => !weightFilter || String(r.weight) === weightFilter)
  return (
    <div>
      <Select className="mb-2" value={weightFilter} onChange={(e) => onWeightFilterChange(e.target.value)}>
        <option value="">All weights</option>
        {WEIGHTS.map((w) => (
          <option key={w} value={w}>
            {w} lbs
          </option>
        ))}
      </Select>
      <div className="max-h-72 space-y-1.5 overflow-y-auto">
        {filtered.map((r) => (
          <CompetitionCard
            key={r.roster_slot_id}
            card={r.competition_card ?? { display_name: r.wrestler?.display_name, weight: r.weight }}
            actions={
              <label className="flex shrink-0 items-center gap-2 pl-2">
                {r.slot_type === 'alternate' && <span className="text-[10px] font-bold uppercase text-ink-600">Alt</span>}
                <input type="checkbox" className="accent-gold-500" checked={selected.includes(r.roster_slot_id)} onChange={() => onToggle(r.roster_slot_id)} />
              </label>
            }
          />
        ))}
        {filtered.length === 0 && <p className="rounded-lg border border-mat-700 bg-mat-900 p-3 text-xs text-ink-600">No roster spots at that weight.</p>}
      </div>
    </div>
  )
}

// Shared by "propose a new trade" and "counter an existing one" - a counter
// is really just a new trade in the opposite direction, pre-seeded from the
// original offer so the receiver isn't starting from a blank slate, but
// fully editable before sending.
function TradeModal({ open, onClose, leagueId, otherMembers, initialReceiverId, initialOffered, initialRequested, onSubmit, submitting, submitLabel }) {
  const [receiverId, setReceiverId] = useState(initialReceiverId ?? '')
  const [offered, setOffered] = useState(initialOffered ?? [])
  const [requested, setRequested] = useState(initialRequested ?? [])
  const [myWeightFilter, setMyWeightFilter] = useState('')
  const [theirWeightFilter, setTheirWeightFilter] = useState('')

  useEffect(() => {
    if (open) {
      setReceiverId(initialReceiverId ?? '')
      setOffered(initialOffered ?? [])
      setRequested(initialRequested ?? [])
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  const { data: myMembership } = useQuery({
    queryKey: ['league', leagueId],
    queryFn: () => api.league(leagueId),
    select: (d) => d?.my_membership,
  })

  const { data: myRoster } = useQuery({
    queryKey: ['league-roster', leagueId, myMembership?.id],
    queryFn: () => api.leagueRoster(leagueId, myMembership.id),
    enabled: !!myMembership?.id && open,
  })

  const { data: receiverRoster } = useQuery({
    queryKey: ['league-roster', leagueId, receiverId],
    queryFn: () => api.leagueRoster(leagueId, Number(receiverId)),
    enabled: !!receiverId && open,
  })

  const toggle = (list, setList) => (slotId) => {
    setList(list.includes(slotId) ? list.filter((x) => x !== slotId) : [...list, slotId])
  }

  const receiverName = otherMembers.find((m) => String(m.membership_id ?? m.id) === String(receiverId))?.user
  const canPickReceiver = initialReceiverId == null

  return (
    <Modal open={open} onClose={onClose} title={submitLabel === 'Send offer' ? 'Propose a trade' : 'Counter this trade'} wide>
      {canPickReceiver ? (
        <Select label="Trade with" value={receiverId} onChange={(e) => { setReceiverId(e.target.value); setRequested([]) }}>
          <option value="">Choose a member…</option>
          {otherMembers.map((m) => (
            <option key={m.membership_id ?? m.id} value={m.membership_id ?? m.id}>
              {m.user?.display_name || m.user?.username}
            </option>
          ))}
        </Select>
      ) : (
        <p className="text-sm text-ink-400">
          Countering back to <span className="font-bold text-ink-100">{receiverName?.display_name || receiverName?.username}</span>
        </p>
      )}

      <div className="mt-4 grid gap-4 sm:grid-cols-2">
        <div>
          <div className="mb-1.5 text-xs font-bold uppercase tracking-wider text-ink-500">You give</div>
          <RosterPicker roster={myRoster} selected={offered} onToggle={toggle(offered, setOffered)} weightFilter={myWeightFilter} onWeightFilterChange={setMyWeightFilter} />
        </div>
        <div>
          <div className="mb-1.5 text-xs font-bold uppercase tracking-wider text-ink-500">You get</div>
          {receiverId ? (
            <RosterPicker roster={receiverRoster} selected={requested} onToggle={toggle(requested, setRequested)} weightFilter={theirWeightFilter} onWeightFilterChange={setTheirWeightFilter} />
          ) : (
            <p className="rounded-lg border border-mat-700 bg-mat-900 p-3 text-xs text-ink-600">Pick a member first.</p>
          )}
        </div>
      </div>

      <div className="mt-5 flex justify-end gap-2">
        <Button variant="ghost" onClick={onClose}>
          Cancel
        </Button>
        <Button loading={submitting} disabled={!receiverId || offered.length === 0 || requested.length === 0} onClick={() => onSubmit({ receiverId, offered, requested })}>
          {submitLabel}
        </Button>
      </div>
    </Modal>
  )
}

export default function LeagueTrades() {
  const { id } = useParams()
  const qc = useQueryClient()
  const me = useAuthStore((s) => s.user)
  const [proposeOpen, setProposeOpen] = useState(false)
  const [counterTrade, setCounterTrade] = useState(null)

  const { data: leagueData } = useQuery({
    queryKey: ['league', id],
    queryFn: () => api.league(id),
  })

  const myMembership = leagueData?.my_membership
  const otherMembers = (leagueData?.members ?? []).filter((m) => m.status === 'active' && m.user?.id !== me?.id)

  const { data: trades, isLoading } = useQuery({
    queryKey: ['league-trades', id],
    queryFn: () => api.leagueTrades(id),
  })

  const invalidateAll = () => {
    qc.invalidateQueries({ queryKey: ['league-trades', id] })
    qc.invalidateQueries({ queryKey: ['league-roster', id] })
  }

  const proposeMutation = useMutation({
    mutationFn: ({ receiverId, offered, requested }) => api.proposeTrade(id, Number(receiverId), offered, requested),
    onSuccess: () => {
      toast.success('Trade proposed')
      setProposeOpen(false)
      invalidateAll()
    },
    onError: (err) => toast.error('Could not propose trade', { body: err.message }),
  })

  const counterMutation = useMutation({
    mutationFn: ({ offered, requested }) => api.counterTrade(counterTrade.trade.id, offered, requested),
    onSuccess: () => {
      toast.success('Counter-offer sent')
      setCounterTrade(null)
      invalidateAll()
    },
    onError: (err) => toast.error('Could not send counter-offer', { body: err.message }),
  })

  const respondMutation = useMutation({
    mutationFn: ({ tradeId, action }) => api.respondToTrade(tradeId, action),
    onSuccess: (_, { action }) => {
      toast.success(action === 'accept' ? 'Trade accepted' : 'Trade rejected')
      invalidateAll()
    },
    onError: (err) => toast.error('Could not respond to trade', { body: err.message }),
  })

  const cancelMutation = useMutation({
    mutationFn: (tradeId) => api.cancelTrade(tradeId),
    onSuccess: () => {
      toast.success('Trade cancelled')
      invalidateAll()
    },
    onError: (err) => toast.error('Could not cancel trade', { body: err.message }),
  })

  const STATUS_COLOR = { proposed: 'gold', countered: 'ink', executed: 'pin', rejected: 'blood', cancelled: 'ink' }

  const openCounter = (trade, items) => {
    const isReceiver = trade.receiver_membership_id === myMembership?.id
    // Flip direction: what I received becomes what I'd give back, and vice
    // versa - a sensible starting point for the counter, not a fixed rule.
    const theyGaveMe = items.filter((it) => it.from_membership_id === trade.proposer_membership_id)
    const iGaveThem = items.filter((it) => it.from_membership_id === trade.receiver_membership_id)
    setCounterTrade({
      trade,
      initialReceiverId: isReceiver ? trade.proposer_membership_id : trade.receiver_membership_id,
      initialOffered: theyGaveMe.map((it) => it.roster_slot_id).filter(Boolean),
      initialRequested: iGaveThem.map((it) => it.roster_slot_id).filter(Boolean),
    })
  }

  return (
    <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} className="space-y-6 py-6">
      <Link to={`/leagues/${id}`} className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to league
      </Link>

      <header className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">
          Trade <span className="text-gold-400">Center</span>
        </h1>
        <Button onClick={() => setProposeOpen(true)}>
          <Plus size={16} /> Propose trade
        </Button>
      </header>

      {isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-20 w-full" />
          ))}
        </div>
      ) : (trades ?? []).length === 0 ? (
        <Card className="p-8 text-center text-sm text-ink-500">No trades yet in this league.</Card>
      ) : (
        <div className="space-y-3">
          {trades.map(({ trade, items }) => {
            const isReceiver = trade.receiver_membership_id === myMembership?.id
            const isProposer = trade.proposer_membership_id === myMembership?.id
            const give = items.filter((it) => it.from_membership_id === trade.proposer_membership_id)
            const get = items.filter((it) => it.from_membership_id === trade.receiver_membership_id)
            const proposerName = leagueData?.members?.find((m) => m.membership_id === trade.proposer_membership_id)?.user
            const receiverName = leagueData?.members?.find((m) => m.membership_id === trade.receiver_membership_id)?.user
            return (
              <Card key={trade.id} className="p-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <Badge color={STATUS_COLOR[trade.status] ?? 'ink'}>{trade.status}</Badge>
                    {trade.counter_of_trade_id && <span className="text-[11px] text-ink-500">counter-offer</span>}
                  </div>
                  {isReceiver && trade.status === 'proposed' && (
                    <div className="flex gap-2">
                      <Button size="sm" variant="secondary" onClick={() => respondMutation.mutate({ tradeId: trade.id, action: 'reject' })}>
                        <X size={14} /> Reject
                      </Button>
                      <Button size="sm" variant="secondary" onClick={() => openCounter(trade, items)}>
                        <Repeat size={14} /> Counter
                      </Button>
                      <Button size="sm" onClick={() => respondMutation.mutate({ tradeId: trade.id, action: 'accept' })}>
                        <Check size={14} /> Accept
                      </Button>
                    </div>
                  )}
                  {isProposer && trade.status === 'proposed' && (
                    <Button size="sm" variant="ghost" onClick={() => cancelMutation.mutate(trade.id)}>
                      <X size={14} /> Cancel
                    </Button>
                  )}
                </div>
                <div className="mt-3 flex items-center gap-3 text-sm">
                  <div className="flex-1">
                    <p className="mb-1 text-[10px] font-bold uppercase tracking-wider text-ink-600">{proposerName?.display_name || proposerName?.username} gives</p>
                    <div className="text-ink-300">{give.map((it) => it.wrestler?.display_name).join(', ') || '—'}</div>
                  </div>
                  <ArrowRightLeft size={16} className="shrink-0 text-ink-600" />
                  <div className="flex-1 text-right">
                    <p className="mb-1 text-[10px] font-bold uppercase tracking-wider text-ink-600">{receiverName?.display_name || receiverName?.username} gives</p>
                    <div className="text-ink-300">{get.map((it) => it.wrestler?.display_name).join(', ') || '—'}</div>
                  </div>
                </div>
              </Card>
            )
          })}
        </div>
      )}

      <TradeModal
        open={proposeOpen}
        onClose={() => setProposeOpen(false)}
        leagueId={id}
        otherMembers={otherMembers}
        onSubmit={(vars) => proposeMutation.mutate(vars)}
        submitting={proposeMutation.isPending}
        submitLabel="Send offer"
      />

      {counterTrade && (
        <TradeModal
          open={!!counterTrade}
          onClose={() => setCounterTrade(null)}
          leagueId={id}
          otherMembers={otherMembers}
          initialReceiverId={counterTrade.initialReceiverId}
          initialOffered={counterTrade.initialOffered}
          initialRequested={counterTrade.initialRequested}
          onSubmit={(vars) => counterMutation.mutate(vars)}
          submitting={counterMutation.isPending}
          submitLabel="Send counter-offer"
        />
      )}
    </motion.div>
  )
}

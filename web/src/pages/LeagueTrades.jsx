import React, { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { ArrowLeft, ArrowRightLeft, Check, Plus, X } from 'lucide-react'
import { api } from '../lib/api'
import { toast, useAuthStore } from '../lib/store'
import { Badge, Button, Card, Modal, Select, Skeleton } from '../components/ui'

function RosterChecklist({ roster, selected, onToggle }) {
  return (
    <div className="max-h-48 space-y-1 overflow-y-auto rounded-lg border border-mat-700 bg-mat-900 p-2">
      {(roster ?? []).map((r) => (
        <label key={r.roster_slot_id} className="flex items-center gap-2 rounded px-2 py-1.5 text-sm hover:bg-mat-800">
          <input
            type="checkbox"
            checked={selected.includes(r.roster_slot_id)}
            onChange={() => onToggle(r.roster_slot_id)}
            className="accent-gold-500"
          />
          <span className="text-ink-200">{r.wrestler?.display_name}</span>
          {r.slot_type === 'alternate' && <span className="text-xs text-ink-600">(alt)</span>}
        </label>
      ))}
      {(roster ?? []).length === 0 && <p className="p-2 text-xs text-ink-600">No active roster spots.</p>}
    </div>
  )
}

export default function LeagueTrades() {
  const { id } = useParams()
  const qc = useQueryClient()
  const me = useAuthStore((s) => s.user)
  const [proposeOpen, setProposeOpen] = useState(false)
  const [receiverId, setReceiverId] = useState('')
  const [offered, setOffered] = useState([])
  const [requested, setRequested] = useState([])

  const { data: leagueData } = useQuery({
    queryKey: ['league', id],
    queryFn: () => api.league(id),
  })

  const myMembership = leagueData?.my_membership
  const otherMembers = (leagueData?.members ?? []).filter((m) => m.status === 'active' && m.user?.id !== me?.id)

  const { data: myRoster } = useQuery({
    queryKey: ['league-roster', id, myMembership?.id],
    queryFn: () => api.leagueRoster(id, myMembership.id),
    enabled: !!myMembership?.id,
  })

  const { data: receiverRoster } = useQuery({
    queryKey: ['league-roster', id, receiverId],
    queryFn: () => api.leagueRoster(id, Number(receiverId)),
    enabled: !!receiverId,
  })

  const { data: trades, isLoading } = useQuery({
    queryKey: ['league-trades', id],
    queryFn: () => api.leagueTrades(id),
  })

  const toggle = (list, setList) => (slotId) => {
    setList(list.includes(slotId) ? list.filter((x) => x !== slotId) : [...list, slotId])
  }

  const proposeMutation = useMutation({
    mutationFn: () => api.proposeTrade(id, Number(receiverId), offered, requested),
    onSuccess: () => {
      toast.success('Trade proposed')
      setProposeOpen(false)
      setOffered([])
      setRequested([])
      setReceiverId('')
      qc.invalidateQueries({ queryKey: ['league-trades', id] })
    },
    onError: (err) => toast.error('Could not propose trade', { body: err.message }),
  })

  const respondMutation = useMutation({
    mutationFn: ({ tradeId, action }) => api.respondToTrade(tradeId, action),
    onSuccess: (_, { action }) => {
      toast.success(action === 'accept' ? 'Trade accepted' : 'Trade rejected')
      qc.invalidateQueries({ queryKey: ['league-trades', id] })
    },
    onError: (err) => toast.error('Could not respond to trade', { body: err.message }),
  })

  const cancelMutation = useMutation({
    mutationFn: (tradeId) => api.cancelTrade(tradeId),
    onSuccess: () => {
      toast.success('Trade cancelled')
      qc.invalidateQueries({ queryKey: ['league-trades', id] })
    },
    onError: (err) => toast.error('Could not cancel trade', { body: err.message }),
  })

  const STATUS_COLOR = { proposed: 'gold', executed: 'pin', rejected: 'blood', cancelled: 'ink' }

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
            return (
              <Card key={trade.id} className="p-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <Badge color={STATUS_COLOR[trade.status] ?? 'ink'}>{trade.status}</Badge>
                  {isReceiver && trade.status === 'proposed' && (
                    <div className="flex gap-2">
                      <Button size="sm" variant="secondary" onClick={() => respondMutation.mutate({ tradeId: trade.id, action: 'reject' })}>
                        <X size={14} /> Reject
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
                  <div className="flex-1 text-ink-300">
                    {give.map((it) => it.wrestler?.display_name).join(', ') || '—'}
                  </div>
                  <ArrowRightLeft size={16} className="shrink-0 text-ink-600" />
                  <div className="flex-1 text-right text-ink-300">
                    {get.map((it) => it.wrestler?.display_name).join(', ') || '—'}
                  </div>
                </div>
              </Card>
            )
          })}
        </div>
      )}

      <Modal open={proposeOpen} onClose={() => setProposeOpen(false)} title="Propose a trade" wide>
        <Select label="Trade with" value={receiverId} onChange={(e) => { setReceiverId(e.target.value); setRequested([]) }}>
          <option value="">Choose a member…</option>
          {otherMembers.map((m) => (
            <option key={m.membership_id ?? m.id} value={m.membership_id ?? m.id}>
              {m.user?.display_name || m.user?.username}
            </option>
          ))}
        </Select>

        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <div>
            <div className="mb-1.5 text-xs font-bold uppercase tracking-wider text-ink-500">You give</div>
            <RosterChecklist roster={myRoster} selected={offered} onToggle={toggle(offered, setOffered)} />
          </div>
          <div>
            <div className="mb-1.5 text-xs font-bold uppercase tracking-wider text-ink-500">You get</div>
            {receiverId ? (
              <RosterChecklist roster={receiverRoster} selected={requested} onToggle={toggle(requested, setRequested)} />
            ) : (
              <p className="rounded-lg border border-mat-700 bg-mat-900 p-3 text-xs text-ink-600">Pick a member first.</p>
            )}
          </div>
        </div>

        <div className="mt-5 flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setProposeOpen(false)}>
            Cancel
          </Button>
          <Button
            loading={proposeMutation.isPending}
            disabled={!receiverId || offered.length === 0 || requested.length === 0}
            onClick={() => proposeMutation.mutate()}
          >
            Send offer
          </Button>
        </div>
      </Modal>
    </motion.div>
  )
}

import React, { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Calendar, Check, Crown, Eye, EyeOff, Lock, Send, Swords, Trophy, X } from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore, toast } from '../lib/store'
import { Avatar, Badge, Button, Card, EmptyState, Skeleton, StatusPill, Tabs } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { normalizeList, displayName } from '../components/tournament/helpers'
import { formatDate, formatPoints, VICTORY_TYPES, cn } from '../lib/utils'

const VT_OPTIONS = Object.entries(VICTORY_TYPES).map(([key, v]) => ({ key, name: v.name }))

function WeightPickRow({ slot, dualMeet, pick, onChange, revealed }) {
  const isHome = pick?.picked_side === 'home'
  const isAway = pick?.picked_side === 'away'

  return (
    <Card className="p-4">
      <div className="mb-3 flex items-center justify-between">
        <span className="font-mono text-xs font-bold uppercase tracking-wider text-gold-400">{slot.weight} lbs</span>
        {revealed && slot.occurred === false && <Badge color="ink">Did not occur</Badge>}
      </div>
      <div className="grid grid-cols-2 gap-2">
        <button
          type="button"
          disabled={revealed}
          onClick={() => onChange(slot.id, { ...pick, picked_side: 'home' })}
          className={cn(
            'flex flex-col items-start rounded-xl border-2 px-3 py-2.5 text-left transition-colors',
            isHome ? 'border-gold-500/70 bg-gold-500/10' : 'border-mat-700 bg-mat-850 hover:border-mat-600',
            revealed && 'cursor-default opacity-90'
          )}
        >
          <span className="text-[10px] font-bold uppercase tracking-wider text-ink-500">{dualMeet.home_team_name}</span>
          <span className="truncate text-sm font-semibold text-ink-100">{slot.home_wrestler_name ?? 'TBD'}</span>
          {revealed && slot.actual_winner_side === 'home' && (
            <span className="mt-1 inline-flex items-center gap-1 text-[10px] font-bold uppercase text-pin-400">
              <Check size={11} /> Winner
            </span>
          )}
        </button>
        <button
          type="button"
          disabled={revealed}
          onClick={() => onChange(slot.id, { ...pick, picked_side: 'away' })}
          className={cn(
            'flex flex-col items-start rounded-xl border-2 px-3 py-2.5 text-left transition-colors',
            isAway ? 'border-gold-500/70 bg-gold-500/10' : 'border-mat-700 bg-mat-850 hover:border-mat-600',
            revealed && 'cursor-default opacity-90'
          )}
        >
          <span className="text-[10px] font-bold uppercase tracking-wider text-ink-500">{dualMeet.away_team_name}</span>
          <span className="truncate text-sm font-semibold text-ink-100">{slot.away_wrestler_name ?? 'TBD'}</span>
          {revealed && slot.actual_winner_side === 'away' && (
            <span className="mt-1 inline-flex items-center gap-1 text-[10px] font-bold uppercase text-pin-400">
              <Check size={11} /> Winner
            </span>
          )}
        </button>
      </div>
      <div className="mt-3">
        <select
          disabled={revealed}
          value={pick?.picked_victory_type ?? ''}
          onChange={(e) => onChange(slot.id, { ...pick, picked_victory_type: e.target.value || null })}
          className="w-full appearance-none rounded-lg border border-mat-600 bg-mat-800 px-3 py-2 text-xs font-semibold text-ink-200 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25 disabled:opacity-70"
        >
          <option value="">How do they win?</option>
          {VT_OPTIONS.map((v) => (
            <option key={v.key} value={v.key}>{v.name}</option>
          ))}
        </select>
      </div>
      {revealed && (
        <div className="mt-2 flex items-center gap-2 text-xs">
          {pick?.is_correct_winner ? (
            <span className="inline-flex items-center gap-1 font-bold text-pin-400"><Check size={12} /> Winner correct</span>
          ) : (
            <span className="inline-flex items-center gap-1 font-bold text-blood-400"><X size={12} /> Winner missed</span>
          )}
          {pick?.is_correct_type && (
            <span className="inline-flex items-center gap-1 font-bold text-gold-400"><Check size={12} /> Type correct</span>
          )}
        </div>
      )}
    </Card>
  )
}

function DualMeetLeaderboard({ dualMeetId }) {
  const me = useAuthStore((s) => s.user)
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['dual-meet-leaderboard', dualMeetId],
    queryFn: () => api.dualMeetLeaderboard(dualMeetId, { per: 50 }),
    staleTime: 15000,
  })
  const { items } = normalizeList(data)

  if (isLoading) return <Skeleton className="h-64 w-full" />
  if (isError) return <ErrorState error={error} onRetry={refetch} title="Leaderboard failed to load" />
  if (!items.length) {
    return <EmptyState icon={<Trophy size={22} />} title="No ranked entries yet" body="Scores appear once the dual meet is locked and graded." />
  }

  return (
    <Card className="overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[520px] text-sm">
          <thead>
            <tr className="text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
              <th className="px-4 py-3">Rank</th>
              <th className="px-4 py-3">Player</th>
              <th className="px-4 py-3 text-right">Winners</th>
              <th className="px-4 py-3 text-right">Tier</th>
              <th className="px-4 py-3 text-right">Points</th>
            </tr>
          </thead>
          <tbody>
            {items.map((row, i) => {
              const u = row.user ?? row
              const isMe = me?.id != null && u.id === me.id
              return (
                <tr key={u.id ?? i} className={cn('border-t border-mat-700/70', isMe && 'border-l-2 border-l-gold-500 bg-gold-500/[0.06]')}>
                  <td className="px-4 py-3">
                    <span className="inline-flex items-center gap-1.5 font-mono font-bold text-ink-100">
                      {row.rank === 1 ? <Crown size={14} className="text-gold-400" /> : row.rank}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <Link to={`/users/${u.id}`} className="flex items-center gap-2.5 hover:text-gold-300">
                      <Avatar user={u} size="xs" />
                      <span className="truncate font-semibold text-ink-100">{displayName(u)}</span>
                    </Link>
                  </td>
                  <td className="px-4 py-3 text-right font-mono text-ink-300">
                    {row.correct_winner_count}/{row.occurred_weight_count}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <Badge color={row.rubric_tier === 'perfect_card' ? 'gold' : 'ink'}>{row.rubric_tier?.replace(/_/g, ' ')}</Badge>
                  </td>
                  <td className="px-4 py-3 text-right font-mono font-bold text-gold-400">{formatPoints(row.total_points)}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </Card>
  )
}

export default function DualMeetDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const token = useAuthStore((s) => s.token)
  const qc = useQueryClient()
  const [tab, setTab] = useState('predict')
  const [picks, setPicks] = useState({}) // weight_slot_id -> {picked_side, picked_victory_type}
  const [entry, setEntry] = useState(null)
  const hydratedRef = useRef(false)

  const dmQuery = useQuery({
    queryKey: ['dual-meet', id],
    queryFn: () => api.dualMeet(id),
    retry: (count, e) => (e?.status === 404 ? false : count < 2),
  })
  const dualMeet = dmQuery.data

  const entryMut = useMutation({
    mutationFn: () => api.createDualMeetEntry(dualMeet.id),
    onSuccess: (res) => setEntry(res),
    onError: (err) => {
      // Expected, not an error: a visitor with no existing entry landing on
      // a dual meet that's no longer open just has nothing to show - not
      // worth surfacing as a failure toast.
      if (err.status === 400 && /not open for entries/i.test(err.message ?? '')) return
      toast.error("Couldn't start your entry", { body: err.message })
    },
  })

  useEffect(() => {
    // Get-or-create: the endpoint always returns an existing entry regardless
    // of the dual meet's current status, and only blocks creating a brand
    // new one when the dual meet isn't open - so this should still run for a
    // locked/completed dual meet, to surface a user's past entry.
    if (token && dualMeet?.id && !entry && !entryMut.isPending && !entryMut.isError) {
      entryMut.mutate()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, dualMeet?.id])

  const entryDetailQuery = useQuery({
    queryKey: ['dual-meet-entry', entry?.id],
    queryFn: () => api.dualMeetEntry(entry.id),
    enabled: !!entry?.id,
  })

  useEffect(() => {
    if (entryDetailQuery.data && !hydratedRef.current) {
      const map = {}
      for (const p of entryDetailQuery.data.picks ?? []) {
        map[p.weight_slot_id] = {
          picked_side: p.picked_side,
          picked_victory_type: p.picked_victory_type,
          is_correct_winner: p.is_correct_winner,
          is_correct_type: p.is_correct_type,
        }
      }
      setPicks(map)
      hydratedRef.current = true
    }
  }, [entryDetailQuery.data])

  const saveMut = useMutation({
    mutationFn: (payload) => api.saveDualMeetPicks(entry.id, payload),
    onError: (err) => toast.error('Could not save picks', { body: err.message }),
  })

  const submitMut = useMutation({
    mutationFn: async (payload) => {
      await api.saveDualMeetPicks(entry.id, payload)
      return api.submitDualMeetEntry(entry.id)
    },
    onSuccess: () => {
      toast.success('Picks submitted!')
      qc.invalidateQueries({ queryKey: ['dual-meet-entry', entry.id] })
    },
    onError: (err) => toast.error('Could not submit', { body: err.message }),
  })

  const visibilityMut = useMutation({
    mutationFn: (isPublic) => api.setDualMeetEntryVisibility(entry.id, isPublic),
    onSuccess: (_res, isPublic) => {
      qc.setQueryData(['dual-meet-entry', entry.id], (old) => (old ? { ...old, entry: { ...old.entry, is_public: isPublic } } : old))
      toast.success(isPublic ? 'Your picks are now public' : 'Your picks are now private')
    },
    onError: (err) => toast.error('Could not update visibility', { body: err.message }),
  })

  if (dmQuery.isLoading) return <Skeleton className="h-96 w-full" />

  if (dmQuery.isError) {
    if (dmQuery.error?.status === 404) {
      return (
        <EmptyState
          icon={<Swords size={22} />}
          title="Dual meet not found"
          body="This dual meet may have been removed."
          action={<Button onClick={() => navigate('/dual-meets')}>Browse dual meets</Button>}
        />
      )
    }
    return <ErrorState error={dmQuery.error} onRetry={dmQuery.refetch} title="Dual meet failed to load" />
  }

  const slots = [...(dualMeet.weight_slots ?? [])].sort((a, b) => (a.display_order ?? 0) - (b.display_order ?? 0))
  const revealed = dualMeet.status === 'completed'
  const isEditable = dualMeet.status === 'open' && (entryDetailQuery.data?.entry?.status ?? 'draft') !== 'locked'
  const onOwnEntry = entryDetailQuery.data?.is_owner !== false
  const currentEntry = entryDetailQuery.data?.entry
  const allPicked = slots.length > 0 && slots.every((s) => picks[s.id]?.picked_side)

  const setPick = (slotId, value) => {
    setPicks((p) => ({ ...p, [slotId]: value }))
  }

  const buildPicksPayload = () =>
    slots
      .filter((s) => picks[s.id]?.picked_side)
      .map((s) => ({
        weight_slot_id: s.id,
        picked_side: picks[s.id].picked_side,
        picked_victory_type: picks[s.id].picked_victory_type ?? null,
      }))

  const savePicks = () => saveMut.mutate(buildPicksPayload())
  const submitPicks = () => submitMut.mutate(buildPicksPayload())

  return (
    <div>
      <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }} className="mb-6">
        <div className="flex flex-wrap items-center gap-3">
          <StatusPill status={dualMeet.status} />
          {dualMeet.year && <span className="font-mono text-sm text-ink-500">{dualMeet.year}</span>}
        </div>
        <h1 className="mt-2 font-display text-2xl uppercase leading-tight tracking-tight text-ink-100 sm:text-3xl">
          {dualMeet.away_team_name} at {dualMeet.home_team_name}
        </h1>
        <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1.5 text-sm text-ink-500">
          {dualMeet.occurred_at && (
            <span className="inline-flex items-center gap-1.5">
              <Calendar size={14} className="text-gold-500/70" /> {formatDate(dualMeet.occurred_at)}
            </span>
          )}
        </div>
      </motion.div>

      <Tabs
        className="mb-6"
        tabs={[
          { key: 'predict', label: token ? 'My Picks' : 'Predict', icon: <Swords size={15} /> },
          { key: 'leaderboard', label: 'Leaderboard', icon: <Trophy size={15} /> },
        ]}
        active={tab}
        onChange={setTab}
      />

      {tab === 'leaderboard' ? (
        <DualMeetLeaderboard dualMeetId={dualMeet.id} />
      ) : !token ? (
        <EmptyState
          icon={<Lock size={22} />}
          title="Sign in to make your picks"
          body="Create a free account to predict this dual meet."
          action={<Button onClick={() => navigate('/login')}>Sign in</Button>}
        />
      ) : dualMeet.status !== 'open' && !currentEntry ? (
        <EmptyState icon={<Lock size={22} />} title="Picks are closed" body="This dual meet is no longer accepting entries." />
      ) : (
        <div>
          <div className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {slots.map((slot) => (
              <WeightPickRow
                key={slot.id}
                slot={slot}
                dualMeet={dualMeet}
                pick={picks[slot.id]}
                onChange={setPick}
                revealed={revealed}
              />
            ))}
          </div>

          {isEditable && onOwnEntry && (
            <div className="flex flex-wrap items-center justify-between gap-3 border-t border-mat-700 pt-4">
              <span className="text-xs text-ink-500">
                {Object.values(picks).filter((p) => p?.picked_side).length} / {slots.length} weights picked
              </span>
              <div className="flex gap-2">
                <Button variant="secondary" onClick={savePicks} loading={saveMut.isPending}>
                  Save draft
                </Button>
                <Button onClick={submitPicks} disabled={!allPicked} loading={submitMut.isPending}>
                  <Send size={15} /> Submit picks
                </Button>
              </div>
            </div>
          )}

          {currentEntry && currentEntry.status !== 'draft' && (
            <div className="mt-4 flex items-center justify-between border-t border-mat-700 pt-4">
              <span className="text-xs font-bold uppercase tracking-wider text-ink-500">
                Status: <Badge color={currentEntry.status === 'scored' ? 'gold' : 'pin'}>{currentEntry.status}</Badge>
              </span>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => visibilityMut.mutate(!currentEntry.is_public)}
                loading={visibilityMut.isPending}
              >
                {currentEntry.is_public ? <Eye size={14} /> : <EyeOff size={14} />}
                {currentEntry.is_public ? 'Public' : 'Private'}
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

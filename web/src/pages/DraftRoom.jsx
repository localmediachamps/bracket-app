import React, { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, ArrowLeft, ChevronDown, ChevronUp, ExternalLink, Play, RefreshCw, Search, SkipForward, Swords } from 'lucide-react'
import { api } from '../lib/api'
import { toast, useAuthStore } from '../lib/store'
import { Avatar, Badge, Button, Card, EmptyState, Input, Select, Skeleton } from '../components/ui'

// seasonWeekId comes from the route: /leagues/:id/draft is the preseason
// draft; /leagues/:id/draft/:seasonWeekId is a tournament-only mini-draft
// scoped to that week. Same component, same endpoints, parameterized - per
// design, these two contexts share one draft engine and one UI.
export default function DraftRoom() {
  const { id, seasonWeekId } = useParams()
  const qc = useQueryClient()
  const me = useAuthStore((s) => s.user)
  const isTournamentDraft = seasonWeekId != null
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [weightClassId, setWeightClassId] = useState('')
  const [expandedWrestlerId, setExpandedWrestlerId] = useState(null)

  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(search.trim()), 300)
    return () => clearTimeout(t)
  }, [search])

  const { data: leagueData } = useQuery({
    queryKey: ['league', id],
    queryFn: () => api.league(id),
  })
  const isCommissioner = leagueData?.my_membership?.role === 'owner' || leagueData?.my_membership?.role === 'commissioner'

  const { data: state, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['draft-state', id, seasonWeekId],
    queryFn: () => api.draftState(id, seasonWeekId),
    refetchInterval: 4000,
    retry: false,
  })

  const { data: weightClasses } = useQuery({
    queryKey: ['league-weight-classes', id],
    queryFn: () => api.leagueWeightClasses(id),
    enabled: !isTournamentDraft,
  })

  const draft = state?.draft
  const members = state?.members ?? []
  const picks = state?.picks ?? []
  const currentMember = members.find((m) => m.is_current)
  const myMember = members.find((m) => m.user?.id === me?.id)
  const isMyTurn = draft?.status === 'in_progress' && myMember?.membership_id === draft?.current_membership_id

  const { data: poolData, isLoading: poolLoading } = useQuery({
    queryKey: ['draft-pool', id, seasonWeekId, debouncedSearch],
    queryFn: () => api.draftPool(id, debouncedSearch || undefined, 1, seasonWeekId),
    enabled: draft?.status === 'in_progress',
  })

  const startMutation = useMutation({
    mutationFn: () => api.startDraft(id, seasonWeekId),
    onSuccess: () => {
      toast.success(isTournamentDraft ? 'Tournament draft started!' : 'Draft started!')
      qc.invalidateQueries({ queryKey: ['draft-state', id, seasonWeekId] })
    },
    onError: (err) => toast.error('Could not start the draft', { body: err.message }),
  })

  const pickMutation = useMutation({
    mutationFn: (wrestlerId) => api.makeDraftPick(id, wrestlerId, { seasonWeekId, seasonWeightClassId: isTournamentDraft ? undefined : Number(weightClassId) }),
    onSuccess: () => {
      toast.success('Pick locked in')
      setSearch('')
      qc.invalidateQueries({ queryKey: ['draft-state', id, seasonWeekId] })
      qc.invalidateQueries({ queryKey: ['draft-pool', id, seasonWeekId] })
    },
    onError: (err) => toast.error('Pick failed', { body: err.message }),
  })

  const autopickMutation = useMutation({
    mutationFn: () => api.autopick(id, seasonWeekId),
    onSuccess: () => {
      toast.success('Autopicked')
      qc.invalidateQueries({ queryKey: ['draft-state', id, seasonWeekId] })
      qc.invalidateQueries({ queryKey: ['draft-pool', id, seasonWeekId] })
    },
    onError: (err) => toast.error('Autopick failed', { body: err.message }),
  })

  const canAutopickForCurrent = myMember && (myMember.membership_id === draft?.current_membership_id || myMember.role === 'owner' || myMember.role === 'commissioner')

  const isComplete = draft?.status === 'complete'

  const picksByRound = useMemo(() => {
    const grouped = new Map()
    for (const p of picks) {
      if (!grouped.has(p.round_number)) grouped.set(p.round_number, [])
      grouped.get(p.round_number).push(p)
    }
    // Reviewing a finished draft reads naturally round 1 first; a live
    // draft in progress is more useful with the newest pick on top.
    return [...grouped.entries()].sort((a, b) => (isComplete ? a[0] - b[0] : b[0] - a[0]))
  }, [picks, isComplete])

  const picksByTeam = useMemo(() => {
    const grouped = new Map()
    for (const p of picks) {
      if (!grouped.has(p.membership_id)) grouped.set(p.membership_id, [])
      grouped.get(p.membership_id).push(p)
    }
    for (const list of grouped.values()) list.sort((a, b) => a.overall_pick_number - b.overall_pick_number)
    return grouped
  }, [picks])

  const [reviewView, setReviewView] = useState('round')

  if (isLoading) {
    return (
      <div className="space-y-6 py-6">
        <Skeleton className="h-10 w-64" />
        <Skeleton className="h-32 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  if (isError && error?.status === 404) {
    return (
      <div className="py-10">
        <EmptyState
          icon={<Swords size={26} />}
          title={isTournamentDraft ? "This tournament's mini-draft hasn't started yet" : "This league's draft hasn't started yet"}
          body={isCommissioner ? 'As the commissioner, you can kick it off now.' : 'Waiting on the league owner or a commissioner to start it.'}
          action={
            isCommissioner ? (
              <Button onClick={() => startMutation.mutate()} loading={startMutation.isPending}>
                <Play size={16} /> Start {isTournamentDraft ? 'tournament draft' : 'draft'}
              </Button>
            ) : (
              <Link to={`/leagues/${id}`}>
                <Button variant="secondary">Back to league</Button>
              </Link>
            )
          }
        />
      </div>
    )
  }

  if (isError || !draft) {
    return (
      <div className="py-10">
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title="Could not load the draft"
          body={error?.message}
          action={
            <Button onClick={() => refetch()} loading={isRefetching}>
              <RefreshCw size={15} /> Try again
            </Button>
          }
        />
      </div>
    )
  }

  return (
    <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} className="space-y-6 py-6">
      <Link to={`/leagues/${id}`} className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to league
      </Link>

      <header className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">
          {isTournamentDraft ? (
            <>
              Tournament <span className="text-gold-400">Draft</span>
            </>
          ) : (
            <>
              Draft <span className="text-gold-400">Room</span>
            </>
          )}
        </h1>
        <Badge color={draft.status === 'in_progress' ? 'pin' : draft.status === 'complete' ? 'ink' : 'gold'}>
          {draft.status === 'in_progress' ? 'Live' : draft.status}
        </Badge>
      </header>

      {isTournamentDraft && (
        <Card className="border-gold-500/30 p-3 text-xs text-ink-400">
          This roster is just for this tournament — everyone's season-long roster goes back to normal once it's over.
        </Card>
      )}

      {/* Draft order strip */}
      <Card className="p-4">
        <div className="mb-2 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">
          Pick {draft.current_pick_number} of {state.total_picks}
        </div>
        <div className="-mx-1 flex gap-2 overflow-x-auto px-1 pb-1 no-scrollbar">
          {members.map((m) => (
            <div
              key={m.membership_id}
              className={
                'flex shrink-0 items-center gap-2 rounded-full border py-1.5 pl-1.5 pr-3 ' +
                (m.is_current ? 'border-gold-500 bg-gold-500/10 shadow-glow-sm' : 'border-mat-700 bg-mat-850')
              }
            >
              <Avatar user={m.user} size="sm" ring={m.is_current} />
              <span className="max-w-28 truncate text-xs font-semibold text-ink-200">
                {m.user?.display_name || m.user?.username}
                {m.user?.id === me?.id && <span className="text-ink-500"> (you)</span>}
              </span>
            </div>
          ))}
        </div>
      </Card>

      {isComplete && (
        <Card className="flex flex-wrap items-center gap-3 p-4">
          <Swords size={20} className="shrink-0 text-gold-400" />
          <div className="min-w-0 flex-1">
            <p className="text-sm font-semibold text-ink-100">The draft is complete — picks are locked, but the board below is still browsable any time.</p>
            <p className="mt-0.5 text-xs text-ink-500">
              {isTournamentDraft
                ? 'Tournament rosters are locked in for this week only.'
                : 'Rosters are locked in — head to the league to set your first lineup.'}
            </p>
          </div>
        </Card>
      )}

      {isComplete ? (
        <Card className="p-4">
          <div className="mb-3 flex items-center justify-between gap-3">
            <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Every pick, {picks.length} total</div>
            <div className="flex items-center gap-1 rounded-lg border border-mat-700 bg-mat-850 p-1">
              <button
                type="button"
                onClick={() => setReviewView('round')}
                className={'rounded-md px-2.5 py-1 text-xs font-bold transition-colors ' + (reviewView === 'round' ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200')}
              >
                By round
              </button>
              <button
                type="button"
                onClick={() => setReviewView('team')}
                className={'rounded-md px-2.5 py-1 text-xs font-bold transition-colors ' + (reviewView === 'team' ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200')}
              >
                By team
              </button>
            </div>
          </div>

          {reviewView === 'round' ? (
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {picksByRound.map(([round, roundPicks]) => (
                <div key={round}>
                  <div className="mb-1.5 text-xs font-bold uppercase tracking-wider text-ink-600">Round {round}</div>
                  <div className="space-y-1">
                    {roundPicks.map((p) => {
                      const member = members.find((m) => m.membership_id === p.membership_id)
                      return (
                        <div key={p.overall_pick_number} className="flex items-center justify-between gap-2 text-xs">
                          <span className="truncate text-ink-300">{p.wrestler?.display_name}</span>
                          <span className="shrink-0 text-ink-600">
                            {member?.user?.display_name || member?.user?.username} · {p.weight}
                          </span>
                        </div>
                      )
                    })}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {members.map((m) => {
                const teamPicks = picksByTeam.get(m.membership_id) ?? []
                return (
                  <div key={m.membership_id}>
                    <div className="mb-1.5 flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-ink-300">
                      <Avatar user={m.user} size="sm" /> {m.user?.display_name || m.user?.username}
                    </div>
                    <div className="space-y-1">
                      {teamPicks.map((p) => (
                        <div key={p.overall_pick_number} className="flex items-center justify-between gap-2 text-xs">
                          <span className="truncate text-ink-300">{p.wrestler?.display_name}</span>
                          <span className="shrink-0 text-ink-600">
                            R{p.round_number} · {p.weight}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </Card>
      ) : (
        <div className="grid gap-4 lg:grid-cols-[1fr_360px]">
          {/* Picker */}
          <Card className="p-4">
            {isMyTurn ? (
              <div className="mb-3 flex items-center gap-2 text-sm font-bold text-gold-400">
                <Swords size={16} /> You're on the clock!
              </div>
            ) : (
              <div className="mb-3 text-sm text-ink-400">
                Waiting on <span className="font-semibold text-ink-200">{currentMember?.user?.display_name || currentMember?.user?.username || '…'}</span>
              </div>
            )}

            <div className={isTournamentDraft ? 'mb-3' : 'mb-3 grid gap-2 sm:grid-cols-[1fr_200px]'}>
              <Input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search wrestlers…"
                disabled={!isMyTurn}
              />
              {!isTournamentDraft && (
                <Select value={weightClassId} onChange={(e) => setWeightClassId(e.target.value)} disabled={!isMyTurn}>
                  <option value="">Weight class…</option>
                  {(weightClasses ?? []).map((wc) => (
                    <option key={wc.id} value={wc.id}>
                      {wc.weight} {wc.name ? `(${wc.name})` : ''}
                    </option>
                  ))}
                </Select>
              )}
            </div>

            {isMyTurn && canAutopickForCurrent && (
              <Button variant="ghost" size="sm" className="mb-3" onClick={() => autopickMutation.mutate()} loading={autopickMutation.isPending}>
                <SkipForward size={14} /> Autopick for me
              </Button>
            )}

            {!isMyTurn && canAutopickForCurrent && (
              <Button variant="ghost" size="sm" className="mb-3" onClick={() => autopickMutation.mutate()} loading={autopickMutation.isPending}>
                <SkipForward size={14} /> Autopick for {currentMember?.user?.display_name || 'them'} (commissioner)
              </Button>
            )}

            {poolLoading ? (
              <div className="space-y-2">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Skeleton key={i} className="h-11 w-full" />
                ))}
              </div>
            ) : (
              <div className="max-h-96 space-y-1.5 overflow-y-auto">
                {(poolData?.wrestlers ?? []).map((w) => {
                  const isExpanded = expandedWrestlerId === w.id
                  const hasRecord = w.record && (w.record.wins > 0 || w.record.losses > 0)
                  return (
                    <div key={w.id} className="rounded-lg border border-mat-700 bg-mat-800">
                      <div className="flex items-center justify-between gap-3 px-3 py-2">
                        <button
                          type="button"
                          className="flex min-w-0 flex-1 items-center gap-1.5 text-left"
                          onClick={() => setExpandedWrestlerId(isExpanded ? null : w.id)}
                        >
                          {hasRecord && (isExpanded ? <ChevronUp size={14} className="shrink-0 text-ink-500" /> : <ChevronDown size={14} className="shrink-0 text-ink-500" />)}
                          <div className="min-w-0">
                            <div className="truncate text-sm font-semibold text-ink-100">
                              {w.name}
                              {w.weight != null && <span className="ml-2 text-xs text-ink-500">{w.weight} lbs</span>}
                            </div>
                            <div className="flex flex-wrap items-center gap-x-2 text-xs text-ink-500">
                              {w.team?.name && <span className="truncate">{w.team.name}</span>}
                              {hasRecord && (
                                <span className="shrink-0 font-mono text-ink-400">
                                  {w.record.wins}-{w.record.losses}
                                  {w.record.falls > 0 && ` · ${w.record.falls} pins`}
                                </span>
                              )}
                            </div>
                          </div>
                        </button>
                        <Button
                          size="sm"
                          disabled={!isMyTurn || (!isTournamentDraft && !weightClassId)}
                          loading={pickMutation.isPending && pickMutation.variables === w.id}
                          onClick={() => pickMutation.mutate(w.id)}
                        >
                          Draft
                        </Button>
                      </div>
                      {isExpanded && hasRecord && (
                        <div className="flex flex-wrap items-center justify-between gap-2 border-t border-mat-700 px-3 py-2 text-xs text-ink-400">
                          <span>
                            {w.record.tech_falls} tech falls · {w.record.majors} majors
                          </span>
                          <Link to={`/wrestlers/${w.id}`} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 font-semibold text-gold-400 hover:text-gold-300">
                            Full profile <ExternalLink size={12} />
                          </Link>
                        </div>
                      )}
                    </div>
                  )
                })}
                {draft.status === 'in_progress' && (poolData?.wrestlers ?? []).length === 0 && (
                  <p className="py-6 text-center text-sm text-ink-500">
                    <Search size={16} className="mx-auto mb-2" />
                    No undrafted wrestlers match that search.
                  </p>
                )}
              </div>
            )}
          </Card>

          {/* Picks so far */}
          <Card className="max-h-[38rem] overflow-y-auto p-4">
            <div className="mb-2 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Picks so far</div>
            {picksByRound.length === 0 ? (
              <p className="text-sm text-ink-500">No picks yet.</p>
            ) : (
              <div className="space-y-4">
                {picksByRound.map(([round, roundPicks]) => (
                  <div key={round}>
                    <div className="mb-1.5 text-xs font-bold uppercase tracking-wider text-ink-600">Round {round}</div>
                    <div className="space-y-1">
                      {roundPicks.map((p) => {
                        const member = members.find((m) => m.membership_id === p.membership_id)
                        return (
                          <div key={p.overall_pick_number} className="flex items-center justify-between gap-2 text-xs">
                            <span className="truncate text-ink-300">{p.wrestler?.display_name}</span>
                            <span className="shrink-0 text-ink-600">
                              {member?.user?.display_name || member?.user?.username} · {p.weight}
                            </span>
                          </div>
                        )
                      })}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </Card>
        </div>
      )}
    </motion.div>
  )
}

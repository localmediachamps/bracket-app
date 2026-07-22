import React, { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import {
  AlertTriangle, ArrowRightLeft, Check, Crown, DoorOpen, ListChecks,
  Play, RefreshCw, Swords, Users, X,
} from 'lucide-react'
import { api } from '../lib/api'
import { toast, useAuthStore } from '../lib/store'
import { Avatar, Button, Card, EmptyState, Modal, Skeleton } from '../components/ui'
import { LeagueStatusBadge } from '../components/league/LeagueCard'
import InviteMemberBox from '../components/league/InviteMemberBox'
import WeeksPanel from '../components/league/WeeksPanel'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

export default function LeagueDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const me = useAuthStore((s) => s.user)
  const [leaveOpen, setLeaveOpen] = useState(false)

  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['league', id],
    queryFn: () => api.league(id),
  })

  const league = data?.league
  const myMembership = data?.my_membership
  const members = data?.members ?? []
  const isOwner = myMembership?.role === 'owner'
  const isCommissioner = isOwner || myMembership?.role === 'commissioner'
  const isActiveMember = myMembership?.status === 'active'
  const isInvited = myMembership?.status === 'invited'

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['league', id] })
    qc.invalidateQueries({ queryKey: ['my-leagues'] })
  }

  const acceptMutation = useMutation({
    mutationFn: () => api.acceptLeagueInvite(id),
    onSuccess: () => {
      toast.success(`You're in ${league.name}!`)
      invalidate()
    },
    onError: (err) => toast.error('Could not accept invite', { body: err.message }),
  })

  const declineMutation = useMutation({
    mutationFn: () => api.declineLeagueInvite(id),
    onSuccess: () => {
      toast.success('Invite declined')
      navigate('/leagues')
    },
    onError: (err) => toast.error('Could not decline invite', { body: err.message }),
  })

  const leaveMutation = useMutation({
    mutationFn: () => api.leaveLeague(id),
    onSuccess: () => {
      toast.success('You left the league')
      invalidate()
      navigate('/leagues')
    },
    onError: (err) => toast.error('Could not leave league', { body: err.message }),
  })

  const startDraftMutation = useMutation({
    mutationFn: () => api.startDraft(id),
    onSuccess: () => {
      toast.success('Draft started!')
      invalidate()
      navigate(`/leagues/${id}/draft`)
    },
    onError: (err) => toast.error('Could not start draft', { body: err.message }),
  })

  if (isLoading) {
    return (
      <div className="space-y-6 py-6">
        <div className="flex items-center gap-4">
          <Skeleton className="h-16 w-16 rounded-2xl" />
          <div className="flex-1">
            <Skeleton className="h-7 w-64" />
            <Skeleton className="mt-2 h-4 w-40" />
          </div>
        </div>
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  if (isError || !league) {
    return (
      <div className="py-10">
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title={error?.status === 404 || error?.status === 403 ? 'League not found' : 'Could not load league'}
          body={error?.status === 404 || error?.status === 403 ? "It may not exist, or you don't have access." : error?.message}
          action={
            error?.status === 404 || error?.status === 403 ? (
              <Link to="/leagues">
                <Button>Back to leagues</Button>
              </Link>
            ) : (
              <Button onClick={() => refetch()} loading={isRefetching}>
                <RefreshCw size={15} /> Try again
              </Button>
            )
          }
        />
      </div>
    )
  }

  const activeMembers = members.filter((m) => m.status === 'active')
  const canStartDraft = isCommissioner && league.status === 'forming' && activeMembers.length >= 2

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="space-y-8 py-6">
      <motion.header variants={rise} className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex min-w-0 items-center gap-4">
          <span className="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl border border-mat-600 bg-mat-800 text-4xl shadow-glow-sm" aria-hidden>
            {league.avatar_emoji || '🤼'}
          </span>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2.5">
              <h1 className="truncate font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">{league.name}</h1>
              <LeagueStatusBadge status={league.status} />
            </div>
            <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-ink-500">
              <span className="inline-flex items-center gap-1.5">
                <Users size={14} />
                {league.member_count ?? activeMembers.length}
                {league.member_limit ? ` / ${league.member_limit}` : ''} members
              </span>
            </div>
            {league.description && <p className="mt-2 max-w-2xl text-sm text-ink-400">{league.description}</p>}
          </div>
        </div>
        <div className="flex shrink-0 flex-wrap gap-2">
          {isActiveMember && !isOwner && (
            <Button variant="danger" size="sm" onClick={() => setLeaveOpen(true)}>
              <DoorOpen size={14} /> Leave
            </Button>
          )}
        </div>
      </motion.header>

      {isInvited && (
        <motion.section variants={rise}>
          <Card className="flex flex-wrap items-center justify-between gap-3 border-gold-500/40 p-5">
            <p className="text-sm text-ink-200">
              <span className="font-bold text-ink-100">You're invited to {league.name}.</span> Join up before the draft starts.
            </p>
            <div className="flex gap-2">
              <Button variant="secondary" size="sm" onClick={() => declineMutation.mutate()} loading={declineMutation.isPending}>
                <X size={14} /> Decline
              </Button>
              <Button size="sm" onClick={() => acceptMutation.mutate()} loading={acceptMutation.isPending}>
                <Check size={14} /> Accept
              </Button>
            </div>
          </Card>
        </motion.section>
      )}

      {isActiveMember && league.status !== 'completed' && (
        <motion.section variants={rise} className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {league.status === 'forming' && canStartDraft && (
            <Button size="lg" className="col-span-full sm:col-span-2" onClick={() => startDraftMutation.mutate()} loading={startDraftMutation.isPending}>
              <Play size={16} /> Start the draft
            </Button>
          )}
          {league.status === 'forming' && !canStartDraft && (
            <Card className="col-span-full p-4 text-center text-sm text-ink-500 sm:col-span-2">
              Waiting for at least 2 active members before the draft can start.
            </Card>
          )}
          {league.status === 'drafting' && (
            <Link to={`/leagues/${id}/draft`} className="col-span-full sm:col-span-2">
              <Button size="lg" className="w-full">
                <Swords size={16} /> Enter draft room
              </Button>
            </Link>
          )}
          {league.status === 'active' && (
            <>
              <Link to={`/leagues/${id}/lineup`}>
                <Button variant="secondary" className="w-full">
                  <ListChecks size={16} /> My lineup
                </Button>
              </Link>
              <Link to={`/leagues/${id}/matchup`}>
                <Button variant="secondary" className="w-full">
                  <Swords size={16} /> This week's matchup
                </Button>
              </Link>
              <Link to={`/leagues/${id}/waivers`}>
                <Button variant="secondary" className="w-full">
                  <Users size={16} /> Waiver wire
                </Button>
              </Link>
              <Link to={`/leagues/${id}/trades`}>
                <Button variant="secondary" className="w-full">
                  <ArrowRightLeft size={16} /> Trades
                </Button>
              </Link>
              <Link to={`/leagues/${id}/draft`}>
                <Button variant="ghost" className="w-full">
                  <Swords size={16} /> Draft results
                </Button>
              </Link>
            </>
          )}
        </motion.section>
      )}

      {isCommissioner && league.status === 'forming' && (
        <motion.section variants={rise}>
          <InviteMemberBox leagueId={id} />
        </motion.section>
      )}

      {isActiveMember && league.status === 'active' && (
        <motion.section variants={rise}>
          <WeeksPanel leagueId={id} isCommissioner={isCommissioner} />
        </motion.section>
      )}

      {members.length > 0 && (
        <motion.section variants={rise} aria-label="Members">
          <div className="mb-2.5 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Members</div>
          <div className="-mx-1 flex gap-2 overflow-x-auto px-1 pb-1 no-scrollbar">
            {members.map((m) => {
              const u = m.user
              const isMemberOwner = m.role === 'owner'
              return (
                <div
                  key={u?.id}
                  className="flex shrink-0 items-center gap-2 rounded-full border border-mat-700 bg-mat-850 py-1.5 pl-1.5 pr-3"
                >
                  <span className="relative">
                    <Avatar user={u} size="sm" ring={isMemberOwner} />
                    {isMemberOwner && (
                      <span className="absolute -right-1 -top-1 flex h-4 w-4 items-center justify-center rounded-full bg-gold-500 text-mat-950" title="League owner">
                        <Crown size={9} strokeWidth={3} />
                      </span>
                    )}
                  </span>
                  <span className="max-w-28 truncate text-xs font-semibold text-ink-200">
                    {u?.display_name || u?.username}
                    {u?.id === me?.id && <span className="text-ink-500"> (you)</span>}
                    {m.status === 'invited' && <span className="text-ink-600"> · invited</span>}
                  </span>
                </div>
              )
            })}
          </div>
        </motion.section>
      )}

      <Modal open={leaveOpen} onClose={() => setLeaveOpen(false)} title="Leave league?">
        <p className="text-sm text-ink-300">
          You'll drop out of <span className="font-bold text-ink-100">{league.name}</span>. Your roster and picks stay in history, but you'll no
          longer be an active member.
        </p>
        <div className="mt-5 flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setLeaveOpen(false)}>
            Stay
          </Button>
          <Button variant="danger" loading={leaveMutation.isPending} onClick={() => leaveMutation.mutate()}>
            Leave league
          </Button>
        </div>
      </Modal>
    </motion.div>
  )
}

import React, { useMemo, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import {
  AlertTriangle, Crown, DoorOpen, Pencil, RefreshCw, Trophy, UserMinus, Users,
} from 'lucide-react'
import { api } from '../lib/api'
import { toast, useAuthStore } from '../lib/store'
import { Avatar, Button, Card, EmptyState, Modal, Skeleton, Tabs } from '../components/ui'
import { plural } from '../lib/utils'
import { PrivacyBadge } from '../components/groups/GroupCard'
import InviteBox from '../components/groups/InviteBox'
import JoinWithCode from '../components/groups/JoinWithCode'
import EditGroupModal from '../components/groups/EditGroupModal'
import GroupLeaderboard, { leaderboardRows } from '../components/groups/GroupLeaderboard'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

const memberUser = (m) => m.user ?? m
const memberId = (m) => m.user_id ?? m.user?.id ?? m.id

export default function GroupDetail() {
  const { id } = useParams()
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const me = useAuthStore((s) => s.user)
  const token = useAuthStore((s) => s.token)

  const [mode, setMode] = useState('bracket')
  const [editOpen, setEditOpen] = useState(false)
  const [leaveOpen, setLeaveOpen] = useState(false)
  const [kickTarget, setKickTarget] = useState(null)

  const { data: group, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['group', id],
    queryFn: () => api.group(id),
  })

  const members = group?.members ?? []
  const myMembership = members.find((m) => memberId(m) === me?.id)
  const myRole = group?.my_role ?? myMembership?.role ?? (group?.owner_id != null && group?.owner_id === me?.id ? 'owner' : null)
  const isMember = myRole != null || !!myMembership
  const canManage = myRole === 'owner' || myRole === 'admin' || !!me?.is_admin
  const canView = isMember || group?.privacy === 'public' || members.length > 0

  const {
    data: lbData,
    isLoading: lbLoading,
    isError: lbError,
    refetch: lbRefetch,
  } = useQuery({
    queryKey: ['group-leaderboard', id, mode],
    queryFn: () => api.groupLeaderboard(id, { mode }),
    enabled: !!group && canView,
    retry: false,
  })
  const rows = useMemo(() => leaderboardRows(lbData), [lbData])

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['group', id] })
    qc.invalidateQueries({ queryKey: ['group-leaderboard', id] })
    qc.invalidateQueries({ queryKey: ['dashboard'] })
  }

  const leaveMutation = useMutation({
    mutationFn: () => api.leaveGroup(id),
    onSuccess: () => {
      toast.success('You left the group')
      invalidate()
      navigate('/groups')
    },
    onError: (err) => toast.error('Could not leave group', { body: err.message }),
  })

  const kickMutation = useMutation({
    mutationFn: (userId) => api.removeGroupMember(id, userId),
    onSuccess: () => {
      toast.success('Member removed')
      setKickTarget(null)
      invalidate()
    },
    onError: (err) => toast.error('Could not remove member', { body: err.message }),
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

  if (isError) {
    return (
      <div className="py-10">
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title={error?.status === 404 ? 'Group not found' : 'Could not load group'}
          body={error?.status === 404 ? 'It may have been deleted, or the link is wrong.' : error?.message}
          action={
            error?.status === 404 ? (
              <Link to="/groups">
                <Button>Back to groups</Button>
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

  const tournament = group.tournament ?? {}
  const tournamentLink = tournament.slug ?? tournament.id ?? group.tournament_id
  const kickUser = kickTarget ? memberUser(kickTarget) : null

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="space-y-8 py-6">
      {/* ── Header ─────────────────────────────────────── */}
      <motion.header variants={rise} className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex min-w-0 items-center gap-4">
          <span className="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl border border-mat-600 bg-mat-800 text-4xl shadow-glow-sm" aria-hidden>
            {group.avatar_emoji || '🤼'}
          </span>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2.5">
              <h1 className="truncate font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">{group.name}</h1>
              <PrivacyBadge privacy={group.privacy} />
            </div>
            <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-ink-500">
              <span className="inline-flex items-center gap-1.5">
                <Users size={14} />
                {group.member_count ?? members.length}
                {group.member_limit ? ` / ${group.member_limit}` : ''} {plural(group.member_count ?? members.length, 'member').split(' ')[1]}
              </span>
              {tournamentLink && (
                <Link to={`/tournaments/${tournamentLink}`} className="inline-flex items-center gap-1.5 font-semibold text-gold-400 hover:text-gold-300">
                  <Trophy size={14} />
                  {tournament.name ?? 'Tournament'}
                  {tournament.year ? ` ${tournament.year}` : ''}
                </Link>
              )}
            </div>
            {group.description && <p className="mt-2 max-w-2xl text-sm text-ink-400">{group.description}</p>}
          </div>
        </div>
        <div className="flex shrink-0 gap-2">
          {canManage && (
            <Button variant="secondary" size="sm" onClick={() => setEditOpen(true)}>
              <Pencil size={14} /> Edit
            </Button>
          )}
          {isMember && myRole !== 'owner' && (
            <Button variant="danger" size="sm" onClick={() => setLeaveOpen(true)}>
              <DoorOpen size={14} /> Leave
            </Button>
          )}
        </div>
      </motion.header>

      {/* ── Join panel (non-members) ───────────────────── */}
      {!isMember && (
        <motion.section variants={rise}>
          {token ? (
            <JoinWithCode
              initialCode={searchParams.get('code') ?? ''}
              onJoined={() => invalidate()}
            />
          ) : (
            <Card className="flex flex-wrap items-center justify-between gap-3 p-5">
              <p className="text-sm text-ink-300">
                <span className="font-bold text-ink-100">Join {group.name}</span> — log in to enter with your invite code.
              </p>
              <Link to="/login" state={{ from: `/groups/${id}${searchParams.get('code') ? `?code=${searchParams.get('code')}` : ''}` }}>
                <Button size="sm">Log in to join</Button>
              </Link>
            </Card>
          )}
        </motion.section>
      )}

      {/* ── Invite box (members, or public groups) ─────── */}
      {(isMember || group.privacy === 'public') && group.invite_code && (
        <motion.section variants={rise}>
          <Card className="p-4">
            <div className="mb-2.5 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Invite your crew</div>
            <InviteBox groupId={group.id} code={group.invite_code} />
          </Card>
        </motion.section>
      )}

      {/* ── Members strip ──────────────────────────────── */}
      {members.length > 0 && (
        <motion.section variants={rise} aria-label="Members">
          <div className="-mx-1 flex gap-2 overflow-x-auto px-1 pb-1 no-scrollbar">
            {members.map((m) => {
              const u = memberUser(m)
              const uid = memberId(m)
              const isOwner = m.role === 'owner' || uid === group.owner_id
              const removable = canManage && !isOwner && uid !== me?.id
              return (
                <div
                  key={uid ?? u.username}
                  className="group/member relative flex shrink-0 items-center gap-2 rounded-full border border-mat-700 bg-mat-850 py-1.5 pl-1.5 pr-3"
                >
                  <span className="relative">
                    <Avatar user={u} size="sm" ring={isOwner} />
                    {isOwner && (
                      <span className="absolute -right-1 -top-1 flex h-4 w-4 items-center justify-center rounded-full bg-gold-500 text-mat-950" title="Group owner">
                        <Crown size={9} strokeWidth={3} />
                      </span>
                    )}
                  </span>
                  <span className="max-w-28 truncate text-xs font-semibold text-ink-200">
                    {u.display_name || u.name || u.username}
                    {uid === me?.id && <span className="text-ink-500"> (you)</span>}
                  </span>
                  {removable && (
                    <button
                      onClick={() => setKickTarget(m)}
                      aria-label={`Remove ${u.display_name || u.username} from group`}
                      className="ml-0.5 rounded-full p-1 text-ink-600 transition-colors hover:bg-blood-500/15 hover:text-blood-400"
                    >
                      <UserMinus size={13} />
                    </button>
                  )}
                </div>
              )
            })}
          </div>
        </motion.section>
      )}

      {/* ── Leaderboard ────────────────────────────────── */}
      <motion.section variants={rise}>
        <Tabs
          tabs={[
            { key: 'bracket', label: 'Bracket' },
            { key: 'pickem', label: "Pick'em" },
          ]}
          active={mode}
          onChange={setMode}
          className="mb-4"
        />
        {!canView ? (
          <Card className="p-8 text-center">
            <p className="text-sm text-ink-400">The leaderboard is visible to members only.</p>
            <p className="mt-1 text-xs text-ink-600">Join with an invite code above to see the standings.</p>
          </Card>
        ) : lbError ? (
          <Card className="flex flex-wrap items-center justify-between gap-3 p-5">
            <span className="text-sm text-ink-400">Leaderboard unavailable{mode === 'pickem' ? ' — this group may not have pick’em entries' : ''}.</span>
            <Button variant="secondary" size="sm" onClick={() => lbRefetch()}>
              <RefreshCw size={14} /> Retry
            </Button>
          </Card>
        ) : (
          <Card className="p-2 sm:p-3">
            <GroupLeaderboard
              rows={rows}
              loading={lbLoading}
              selfId={me?.id}
              emptyLabel="No ranked entries yet — standings appear once picks are submitted."
            />
          </Card>
        )}
      </motion.section>

      {/* ── Modals ─────────────────────────────────────── */}
      <EditGroupModal open={editOpen} onClose={() => setEditOpen(false)} group={group} />

      <Modal open={leaveOpen} onClose={() => setLeaveOpen(false)} title="Leave group?">
        <p className="text-sm text-ink-300">
          You'll drop off the <span className="font-bold text-ink-100">{group.name}</span> leaderboard. You can rejoin later with the invite code.
        </p>
        <div className="mt-5 flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setLeaveOpen(false)}>
            Stay
          </Button>
          <Button variant="danger" loading={leaveMutation.isPending} onClick={() => leaveMutation.mutate()}>
            Leave group
          </Button>
        </div>
      </Modal>

      <Modal open={!!kickTarget} onClose={() => setKickTarget(null)} title="Remove member?">
        {kickTarget && (
          <>
            <div className="flex items-center gap-3">
              <Avatar user={kickUser} size="md" />
              <p className="text-sm text-ink-300">
                Remove <span className="font-bold text-ink-100">{kickUser?.display_name || kickUser?.name || kickUser?.username}</span> from{' '}
                <span className="font-bold text-ink-100">{group.name}</span>? Their entries stay scored; they just leave the group.
              </p>
            </div>
            <div className="mt-5 flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setKickTarget(null)}>
                Cancel
              </Button>
              <Button variant="danger" loading={kickMutation.isPending} onClick={() => kickMutation.mutate(memberId(kickTarget))}>
                Remove
              </Button>
            </div>
          </>
        )}
      </Modal>
    </motion.div>
  )
}

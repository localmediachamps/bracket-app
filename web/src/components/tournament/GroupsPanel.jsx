import React from 'react'
import { useNavigate } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Users, Plus, ArrowRight } from 'lucide-react'
import { api } from '../../lib/api'
import { useAuthStore, toast } from '../../lib/store'
import { Badge, Button, Card, EmptyState, Skeleton } from '../ui'
import { plural } from '../../lib/utils'
import { normalizeList } from './helpers'
import { ErrorState } from './Feedback'

/**
 * GroupsPanel — public groups for a tournament + create CTA.
 * Public groups only expose invite_code to joiners when the API chooses to;
 * when present we join inline, otherwise we route to the group detail page.
 */
export default function GroupsPanel({ tournament }) {
  const token = useAuthStore((s) => s.token)
  const navigate = useNavigate()
  const qc = useQueryClient()

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['tournament-groups', tournament.id],
    queryFn: () => api.tournamentGroups(tournament.id),
    staleTime: 30000,
  })

  const joinMut = useMutation({
    mutationFn: (code) => api.joinGroup(code),
    onSuccess: () => {
      toast.success('You joined the group', { body: 'Your entry now counts on their board too.' })
      qc.invalidateQueries({ queryKey: ['tournament-groups', tournament.id] })
    },
    onError: (e) => toast.error(e.message || 'Could not join group'),
  })

  const { items: groups } = normalizeList(data)

  const handleJoin = (g) => {
    if (!token) {
      navigate('/login', { state: { from: `/tournaments/${tournament.slug ?? tournament.id}?tab=groups` } })
      return
    }
    if (g.invite_code) joinMut.mutate(g.invite_code)
    else navigate(`/groups/${g.id}`)
  }

  if (isLoading) {
    return (
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3" aria-busy="true" aria-label="Loading groups">
        {Array.from({ length: 3 }).map((_, i) => (
          <Skeleton key={i} className="h-36 w-full" />
        ))}
      </div>
    )
  }

  if (isError) return <ErrorState error={error} onRetry={refetch} title="Groups failed to load" />

  return (
    <div>
      {groups.length === 0 ? (
        <EmptyState
          icon={<Users size={22} />}
          title="No public groups yet"
          body="Start a crew with your friends, wrestling club, or family — every group gets its own leaderboard."
          action={
            <Button onClick={() => navigate(`/groups/new?tournament=${tournament.id}`)}>
              <Plus size={15} /> Create a group
            </Button>
          }
        />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {groups.map((g, i) => (
            <motion.div
              key={g.id}
              initial={{ opacity: 0, y: 14 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: Math.min(i * 0.05, 0.3), duration: 0.3 }}
            >
              <Card hover className="flex h-full flex-col p-5">
                <div className="flex items-start gap-3">
                  <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border border-mat-600 bg-mat-800 text-2xl">
                    {g.avatar_emoji || '🤼'}
                  </span>
                  <div className="min-w-0 flex-1">
                    <h3 className="truncate font-display text-sm uppercase tracking-wide text-ink-100">{g.name}</h3>
                    <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-ink-500">
                      <span className="inline-flex items-center gap-1">
                        <Users size={12} /> {plural(g.member_count ?? 0, 'member')}
                      </span>
                      {g.privacy === 'public' && <Badge color="pin">Public</Badge>}
                    </div>
                  </div>
                </div>
                <div className="mt-auto flex items-center justify-between pt-4">
                  <Button
                    size="sm"
                    variant={g.invite_code ? 'primary' : 'secondary'}
                    loading={joinMut.isPending && joinMut.variables === g.invite_code}
                    onClick={() => handleJoin(g)}
                  >
                    {g.invite_code ? 'Join' : 'View'}
                  </Button>
                  <button
                    onClick={() => navigate(`/groups/${g.id}`)}
                    className="inline-flex items-center gap-1 text-xs font-bold text-gold-500 hover:text-gold-300"
                    aria-label={`Open ${g.name}`}
                  >
                    Open <ArrowRight size={12} />
                  </button>
                </div>
              </Card>
            </motion.div>
          ))}

          {/* Create card */}
          <motion.button
            initial={{ opacity: 0, y: 14 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: Math.min(groups.length * 0.05, 0.3), duration: 0.3 }}
            onClick={() => navigate(token ? `/groups/new?tournament=${tournament.id}` : '/login', token ? undefined : { state: { from: `/groups/new?tournament=${tournament.id}` } })}
            className="flex min-h-[9rem] flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-mat-600 bg-mat-900/40 p-5 text-ink-500 transition-colors hover:border-gold-500/40 hover:text-gold-400"
          >
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-mat-800">
              <Plus size={18} />
            </span>
            <span className="text-sm font-bold">Create a group</span>
            <span className="text-xs">Private leaderboard in seconds</span>
          </motion.button>
        </div>
      )}
    </div>
  )
}

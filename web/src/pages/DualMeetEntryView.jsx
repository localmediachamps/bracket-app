import React from 'react'
import { Link, useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, ArrowLeft, Check, RefreshCw, Swords, X } from 'lucide-react'
import { api } from '../lib/api'
import { Badge, Button, Card, EmptyState, Skeleton, StatusPill } from '../components/ui'
import { formatPoints, cn } from '../lib/utils'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

export default function DualMeetEntryView() {
  const { id } = useParams()

  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['dual-meet-entry-view', id],
    queryFn: () => api.dualMeetEntry(id),
    retry: false,
  })

  const entry = data?.entry ?? {}
  const entryUser = data?.user ?? null
  const isOwner = data?.is_owner ?? false
  const dualMeet = data?.dual_meet ?? {}
  const picks = (data?.picks ?? []).slice().sort((a, b) => (a.weight ?? 999) - (b.weight ?? 999))
  const revealed = dualMeet.status === 'completed'

  if (isLoading) {
    return (
      <div className="space-y-6 py-6">
        <Skeleton className="h-9 w-80" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  if (isError) {
    const denied = error?.status === 403
    return (
      <div className="py-10">
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title={denied ? 'This entry is private' : error?.status === 404 ? 'Entry not found' : 'Could not load entry'}
          body={denied ? "You can only view your own entries, or ones a player has made public." : error?.message}
          action={
            denied || error?.status === 404 ? (
              <Link to="/dual-meets">
                <Button>Browse dual meets</Button>
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

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="space-y-6 py-6">
      <motion.header variants={rise} className="flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0">
          <Link
            to={dualMeet.slug ? `/dual-meets/${dualMeet.slug}` : '/dual-meets'}
            className="mb-2 inline-flex items-center gap-1 text-xs font-bold uppercase tracking-wider text-ink-500 transition-colors hover:text-gold-400"
          >
            <ArrowLeft size={14} /> Dual meet
          </Link>
          <div className="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-[0.16em] text-gold-400">
            <Swords size={12} /> Dual Meet Picks
            {!isOwner && (entryUser?.display_name || entryUser?.username) && (
              <span className="text-ink-500">· {entryUser.display_name || entryUser.username}'s picks</span>
            )}
          </div>
          <div className="mt-1 flex flex-wrap items-center gap-3">
            <h1 className="font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">
              {dualMeet.name ?? 'Dual meet entry'}
            </h1>
            {dualMeet.year && <span className="font-mono text-sm text-ink-500">{dualMeet.year}</span>}
            <StatusPill status={entry.status} />
          </div>
          <div className="mt-3 flex flex-wrap items-end gap-x-8 gap-y-3">
            <div>
              <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Points</div>
              <div className="font-mono text-3xl font-bold tracking-tight text-gold-400">{formatPoints(entry.total_points)}</div>
            </div>
            {entry.rank != null && (
              <div>
                <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Rank</div>
                <div className="font-mono text-2xl font-bold text-ink-100">#{entry.rank}</div>
              </div>
            )}
            {entry.rubric_tier && (
              <div>
                <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Tier</div>
                <Badge color={entry.rubric_tier === 'perfect_card' ? 'gold' : 'ink'}>{entry.rubric_tier.replace(/_/g, ' ')}</Badge>
              </div>
            )}
          </div>
        </div>
      </motion.header>

      <motion.section variants={rise}>
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[560px] border-collapse text-sm">
              <thead>
                <tr className="border-b border-mat-700 text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
                  <th className="w-20 px-4 py-2.5">Weight</th>
                  <th className="px-4 py-2.5">Picked</th>
                  <th className="px-4 py-2.5">Victory type</th>
                  {revealed && <th className="px-4 py-2.5 text-right">Result</th>}
                </tr>
              </thead>
              <tbody>
                {picks.length === 0 ? (
                  <tr>
                    <td colSpan={revealed ? 4 : 3} className="px-4 py-8 text-center text-sm text-ink-500">No picks yet.</td>
                  </tr>
                ) : (
                  picks.map((p) => {
                    const pickedName = p.picked_side === 'home' ? p.home_wrestler_name : p.away_wrestler_name
                    return (
                      <tr key={p.id} className="border-b border-mat-800 last:border-0">
                        <td className="px-4 py-3 font-mono text-xs font-bold text-gold-400">{p.weight ?? '—'} lbs</td>
                        <td className="px-4 py-3 font-semibold text-ink-100">{pickedName ?? '—'}</td>
                        <td className="px-4 py-3 text-ink-400">{p.picked_victory_type ?? '—'}</td>
                        {revealed && (
                          <td className="px-4 py-3 text-right">
                            <span className={cn('inline-flex items-center gap-1 text-xs font-bold', p.is_correct_winner ? 'text-pin-400' : 'text-blood-400')}>
                              {p.is_correct_winner ? <Check size={13} /> : <X size={13} />}
                              {p.is_correct_winner ? 'Correct' : 'Missed'}
                            </span>
                          </td>
                        )}
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>
        </Card>
      </motion.section>
    </motion.div>
  )
}

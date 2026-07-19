import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import {
  AlertTriangle, Bell, BellOff, CheckCheck, ChevronLeft, ChevronRight, Clock,
  ListChecks, Lock, RefreshCw, TrendingUp, Trophy, Users,
} from 'lucide-react'
import { api } from '../lib/api'
import { toast } from '../lib/store'
import { Button, Card, EmptyState, Skeleton } from '../components/ui'
import { cn, formatDate } from '../lib/utils'

/* ── tiny relative time helper (local to this page) ───── */
export function relativeTime(d) {
  if (!d) return ''
  const t = new Date(d).getTime()
  if (isNaN(t)) return ''
  const s = Math.max(0, (Date.now() - t) / 1000)
  if (s < 45) return 'just now'
  if (s < 3600) return `${Math.floor(s / 60)}m ago`
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`
  if (s < 86400 * 7) return `${Math.floor(s / 86400)}d ago`
  return formatDate(d, { year: undefined })
}

/* ── type → icon/tint map ─────────────────────────────── */
const TYPE_MAP = [
  { match: (t) => t === 'entry_locked', icon: Lock, tone: 'gold' },
  { match: (t) => t === 'deadline_soon' || t === 'entry_incomplete', icon: Clock, tone: 'blood' },
  { match: (t) => t === 'rank_change', icon: TrendingUp, tone: 'pin' },
  { match: (t) => t?.startsWith('group_'), icon: Users, tone: 'gold' },
  { match: (t) => t === 'result_entered', icon: ListChecks, tone: 'pin' },
  { match: (t) => t?.startsWith('tournament_'), icon: Trophy, tone: 'gold' },
]
const toneClass = {
  gold: 'bg-gold-500/12 text-gold-400',
  blood: 'bg-blood-500/12 text-blood-400',
  pin: 'bg-pin-500/12 text-pin-400',
  ink: 'bg-mat-700/60 text-ink-300',
}
function typeStyle(type) {
  const hit = TYPE_MAP.find((x) => x.match(type))
  return hit ?? { icon: Bell, tone: 'ink' }
}

function deepLink(data) {
  if (!data) return null
  if (data.entry_id) return `/entries/${data.entry_id}/review`
  if (data.group_id) return `/groups/${data.group_id}`
  if (data.tournament_id) return `/tournaments/${data.tournament_id}`
  return null
}

const PER = 20

export default function Notifications() {
  const [page, setPage] = useState(1)
  const navigate = useNavigate()
  const qc = useQueryClient()

  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['notifications', 'page', page],
    queryFn: () => api.notifications({ page, per: PER }),
  })

  const invalidateAll = () => {
    qc.invalidateQueries({ queryKey: ['notifications'] })
  }

  const markAll = useMutation({
    mutationFn: api.markAllNotificationsRead,
    onSuccess: () => {
      toast.success('All caught up')
      invalidateAll()
    },
    onError: (err) => toast.error('Could not mark all read', { body: err.message }),
  })

  const markOne = useMutation({
    mutationFn: (id) => api.markNotificationRead(id),
    onSettled: invalidateAll,
  })

  const items = data?.items ?? data?.notifications ?? (Array.isArray(data) ? data : [])
  const total = data?.total ?? data?.total_count ?? null
  const per = data?.per ?? PER
  const totalPages = total != null ? Math.max(1, Math.ceil(total / per)) : null
  const hasUnread = items.some((n) => !n.read_at) || (data?.unread_count ?? 0) > 0

  const openNotification = (n) => {
    if (!n.read_at) markOne.mutate(n.id)
    const link = deepLink(n.data)
    if (link) navigate(link)
  }

  return (
    <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} className="mx-auto max-w-3xl py-6">
      <header className="mb-6 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl uppercase tracking-tight text-ink-100 sm:text-4xl">
            Notifi<span className="text-gold-400">cations</span>
          </h1>
          {data?.unread_count > 0 && (
            <p className="mt-1.5 text-sm text-ink-500">
              <span className="font-bold text-gold-400">{data.unread_count}</span> unread
            </p>
          )}
        </div>
        <Button variant="secondary" size="sm" onClick={() => markAll.mutate()} loading={markAll.isPending} disabled={!hasUnread}>
          <CheckCheck size={15} /> Mark all read
        </Button>
      </header>

      {isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-[72px] w-full" />
          ))}
        </div>
      ) : isError ? (
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title="Notifications failed to load"
          body={error?.message}
          action={
            <Button onClick={() => refetch()} loading={isRefetching}>
              <RefreshCw size={15} /> Try again
            </Button>
          }
        />
      ) : items.length === 0 ? (
        <EmptyState
          icon={<BellOff size={26} />}
          title="Quiet in the arena"
          body="Deadlines, results, rank changes, and group activity will land here."
        />
      ) : (
        <>
          <Card className="divide-y divide-mat-800 overflow-hidden">
            {items.map((n, i) => {
              const { icon: Icon, tone } = typeStyle(n.type)
              const unread = !n.read_at
              const link = deepLink(n.data)
              return (
                <motion.button
                  key={n.id}
                  type="button"
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: Math.min(i * 0.025, 0.3) }}
                  onClick={() => openNotification(n)}
                  className={cn(
                    'relative flex w-full items-start gap-3.5 px-4 py-4 text-left transition-colors hover:bg-mat-800/60 sm:px-5',
                    unread && 'bg-gold-500/[0.03]'
                  )}
                  aria-label={`${unread ? 'Unread: ' : ''}${n.title}${link ? ' — open' : ''}`}
                >
                  {unread && <span className="absolute inset-y-0 left-0 w-[3px] bg-gold-500" aria-hidden />}
                  <span className={cn('mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full', toneClass[tone])}>
                    <Icon size={16} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className={cn('flex items-center gap-2 text-sm', unread ? 'font-bold text-ink-100' : 'font-semibold text-ink-300')}>
                      <span className="truncate">{n.title}</span>
                      {unread && <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-gold-400" aria-hidden />}
                    </span>
                    {n.body && <span className="mt-0.5 line-clamp-2 block text-xs leading-relaxed text-ink-500">{n.body}</span>}
                    <span className="mt-1 block text-[11px] font-medium text-ink-600">{relativeTime(n.created_at)}</span>
                  </span>
                  {link && <ChevronRight size={16} className="mt-1 shrink-0 text-ink-600" />}
                </motion.button>
              )
            })}
          </Card>

          {/* pagination */}
          {(totalPages == null || totalPages > 1) && (
            <div className="mt-5 flex items-center justify-center gap-3">
              <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>
                <ChevronLeft size={14} /> Newer
              </Button>
              <span className="font-mono text-xs text-ink-500">
                Page {page}
                {totalPages != null ? ` of ${totalPages}` : ''}
              </span>
              <Button
                variant="secondary"
                size="sm"
                disabled={totalPages != null ? page >= totalPages : items.length < per}
                onClick={() => setPage((p) => p + 1)}
              >
                Older <ChevronRight size={14} />
              </Button>
            </div>
          )}
        </>
      )}
    </motion.div>
  )
}

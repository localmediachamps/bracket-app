import React from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Plus, FileUp, Trophy, Users, Radio, Pencil, ArrowRight, ScrollText } from 'lucide-react'
import { api } from '../../lib/api'
import { Badge, Button, Card, CardSkeleton, EmptyState, Skeleton, Stat, StatusPill } from '../../components/ui'
import { formatDateTime } from '../../lib/utils'
import { PageHeader, ErrorState } from '../../components/admin/AdminCommon'
import { actorLabel, auditActionColor, timeAgo } from '../../components/admin/adminUtils'

export default function AdminDashboard() {
  const tQ = useQuery({ queryKey: ['admin', 'tournaments'], queryFn: () => api.adminTournaments() })
  const auditQ = useQuery({ queryKey: ['admin', 'audit', 'recent'], queryFn: () => api.adminAuditLogs({ per: 8 }) })

  const items = Array.isArray(tQ.data) ? tQ.data : tQ.data?.items ?? []
  const auditItems = Array.isArray(auditQ.data) ? auditQ.data : auditQ.data?.items ?? []

  const totalTournaments = tQ.data?.total ?? items.length
  const openLive = items.filter((t) => ['open', 'locked', 'live'].includes(t.status)).length
  const drafts = items.filter((t) => t.status === 'draft').length
  const totalPlayers = items.reduce((s, t) => s + (Number(t.entry_count) || 0), 0)

  return (
    <div>
      <PageHeader
        title="Admin Dashboard"
        sub="Tournaments, players and everything happening on the mat."
        actions={
          <>
            <Link to="/admin/tournaments/new?mode=pdf">
              <Button variant="secondary" size="md"><FileUp size={16} /> Upload PDF bracket</Button>
            </Link>
            <Link to="/admin/tournaments/new">
              <Button variant="primary" size="md"><Plus size={16} /> New tournament</Button>
            </Link>
          </>
        }
      />

      {/* stat cards */}
      <div className="mb-8 grid grid-cols-2 gap-3 lg:grid-cols-4">
        {tQ.isLoading ? (
          <>
            <Skeleton className="h-[92px]" />
            <Skeleton className="h-[92px]" />
            <Skeleton className="h-[92px]" />
            <Skeleton className="h-[92px]" />
          </>
        ) : (
          [
            { label: 'Tournaments', value: totalTournaments, icon: <Trophy size={16} />, sub: `${drafts} in draft` },
            { label: 'Open / Live', value: openLive, icon: <Radio size={16} />, sub: 'accepting or scoring' },
            { label: 'Players entered', value: totalPlayers, icon: <Users size={16} />, sub: 'Σ entries across tournaments' },
            { label: 'Drafts', value: drafts, icon: <Pencil size={16} />, sub: 'not yet published' },
          ].map((s, i) => (
            <motion.div key={s.label} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}>
              <Stat label={s.label} value={s.value} sub={s.sub} icon={s.icon} />
            </motion.div>
          ))
        )}
      </div>

      {tQ.isError ? (
        <ErrorState error={tQ.error} onRetry={() => tQ.refetch()} title="Couldn't load tournaments" />
      ) : tQ.isLoading ? (
        <div className="grid gap-3">
          <CardSkeleton />
          <CardSkeleton />
        </div>
      ) : items.length === 0 ? (
        <EmptyState
          icon={<Trophy size={24} />}
          title="No tournaments yet"
          body="Create your first tournament manually, or let the AI build it from a bracket PDF."
          action={
            <Link to="/admin/tournaments/new">
              <Button variant="primary"><Plus size={16} /> New tournament</Button>
            </Link>
          }
        />
      ) : (
        <Card className="mb-8 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[760px] text-sm">
              <thead>
                <tr className="border-b border-mat-700 text-left text-[10px] font-bold uppercase tracking-[0.12em] text-ink-500">
                  <th className="px-4 py-3">Tournament</th>
                  <th className="px-4 py-3">Year</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3 text-right">Weights</th>
                  <th className="px-4 py-3 text-right">Entries</th>
                  <th className="px-4 py-3">Locks</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.map((t, i) => (
                  <motion.tr
                    key={t.id}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: Math.min(i * 0.03, 0.3) }}
                    className="border-b border-mat-700/60 last:border-0 hover:bg-mat-800/40"
                  >
                    <td className="px-4 py-3">
                      <Link to={`/admin/tournaments/${t.id}`} className="font-semibold text-ink-100 hover:text-gold-400">
                        {t.name}
                      </Link>
                      {t.location && <span className="block text-xs text-ink-600">{t.location}</span>}
                    </td>
                    <td className="px-4 py-3 font-mono text-ink-300">{t.year}</td>
                    <td className="px-4 py-3"><StatusPill status={t.status} /></td>
                    <td className="px-4 py-3 text-right font-mono text-ink-300">
                      {t.weight_class_count ?? t.weight_classes?.length ?? '—'}
                    </td>
                    <td className="px-4 py-3 text-right font-mono text-ink-300">{t.entry_count ?? 0}</td>
                    <td className="px-4 py-3 text-xs text-ink-500">{t.locks_at ? formatDateTime(t.locks_at) : '—'}</td>
                    <td className="px-4 py-3 text-right">
                      <Link to={`/admin/tournaments/${t.id}`}>
                        <Button variant="ghost" size="sm">Manage <ArrowRight size={14} /></Button>
                      </Link>
                    </td>
                  </motion.tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {/* recent audit activity */}
      <div className="mb-3 flex items-center justify-between">
        <h2 className="flex items-center gap-2 font-display text-sm uppercase tracking-wide text-ink-100">
          <ScrollText size={15} className="text-gold-500" /> Recent activity
        </h2>
        <Link to="/admin/audit" className="text-xs font-bold text-gold-400 hover:text-gold-300">Full audit log →</Link>
      </div>
      {auditQ.isLoading ? (
        <div className="grid gap-2">
          <Skeleton className="h-12" />
          <Skeleton className="h-12" />
          <Skeleton className="h-12" />
        </div>
      ) : auditQ.isError ? (
        <ErrorState error={auditQ.error} onRetry={() => auditQ.refetch()} title="Couldn't load activity" />
      ) : auditItems.length === 0 ? (
        <Card className="p-6 text-center text-sm text-ink-500">No admin activity recorded yet.</Card>
      ) : (
        <Card className="divide-y divide-mat-700/60">
          {auditItems.map((row) => (
            <div key={row.id} className="flex items-center gap-3 px-4 py-3">
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm text-ink-200">
                  <span className="font-semibold text-ink-100">{actorLabel(row)}</span>{' '}
                  <span className="text-ink-500">performed</span>{' '}
                  <Badge color={auditActionColor(row.action)} className="mx-0.5">{row.action}</Badge>{' '}
                  <span className="text-ink-500">on</span>{' '}
                  <span className="font-mono text-xs text-ink-300">{row.entity_type}{row.entity_id ? ` #${row.entity_id}` : ''}</span>
                </p>
              </div>
              <span className="shrink-0 text-xs text-ink-600" title={formatDateTime(row.created_at)}>{timeAgo(row.created_at)}</span>
            </div>
          ))}
        </Card>
      )}
    </div>
  )
}

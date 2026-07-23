import React from 'react'
import { Link, useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, ArrowLeft, Download, RefreshCw, Scale } from 'lucide-react'
import { api } from '../lib/api'
import { Button, Card, EmptyState, Skeleton, StatusPill } from '../components/ui'
import { formatPoints } from '../lib/utils'
import { exportPickemPDF } from '../lib/pdfExport'
import { toast } from '../lib/store'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

const weightLabel = (w) => (w == null ? '—' : typeof w === 'number' ? `${w} lbs` : String(w))

export default function PickemEntryView() {
  const { id } = useParams()

  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['pickem-entry-view', id],
    queryFn: () => api.pickemEntry(id),
    retry: false,
  })

  const entry = data?.entry ?? {}
  const entryUser = data?.user ?? null
  const isOwner = data?.is_owner ?? false
  const picks = (data?.picks ?? []).slice().sort(
    (a, b) => (a.weight_class?.weight ?? 999) - (b.weight_class?.weight ?? 999)
  )

  const tournamentId = entry.tournament_id
  const { data: tData } = useQuery({
    queryKey: ['tournament', tournamentId],
    queryFn: () => api.tournament(tournamentId),
    enabled: !!tournamentId,
  })
  const tournament = tData ?? {}
  const tournamentKey = tournament.slug ?? tournamentId

  const handleDownloadPdf = () => {
    try {
      exportPickemPDF({
        tournamentName: tournament.name,
        tournamentYear: tournament.year,
        ownerName: !isOwner ? (entryUser?.display_name || entryUser?.username) : null,
        entry,
        picks,
      })
    } catch (err) {
      toast.error('Could not generate PDF', { body: err.message })
    }
  }

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
          title={denied ? "This entry is private" : error?.status === 404 ? 'Entry not found' : 'Could not load entry'}
          body={denied ? "You can only view your own entries, or ones a player has made public." : error?.message}
          action={
            denied || error?.status === 404 ? (
              <Link to="/tournaments">
                <Button>Browse tournaments</Button>
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
            to={tournamentKey ? `/tournaments/${tournamentKey}` : '/tournaments'}
            className="mb-2 inline-flex items-center gap-1 text-xs font-bold uppercase tracking-wider text-ink-500 transition-colors hover:text-gold-400"
          >
            <ArrowLeft size={14} /> Hub
          </Link>
          <div className="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-[0.16em] text-gold-400">
            <Scale size={12} /> Pick'em
            {!isOwner && (entryUser?.display_name || entryUser?.username) && (
              <span className="text-ink-500">
                · {entryUser.display_name || entryUser.username}'s picks
              </span>
            )}
          </div>
          <div className="mt-1 flex flex-wrap items-center gap-3">
            <h1 className="font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">
              {tournament.name ?? "Pick'em entry"}
            </h1>
            {tournament.year && <span className="font-mono text-sm text-ink-500">{tournament.year}</span>}
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
            {entry.points_used != null && (
              <div>
                <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Budget used</div>
                <div className="font-mono text-2xl font-bold text-ink-100">{entry.points_used}</div>
              </div>
            )}
          </div>
        </div>
        <Button variant="secondary" onClick={handleDownloadPdf} disabled={picks.length === 0}>
          <Download size={15} /> Download PDF
        </Button>
      </motion.header>

      <motion.section variants={rise}>
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[560px] border-collapse text-sm">
              <thead>
                <tr className="border-b border-mat-700 text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
                  <th className="w-20 px-4 py-2.5">Weight</th>
                  <th className="px-4 py-2.5">Wrestler</th>
                  <th className="px-4 py-2.5 text-right">Cost</th>
                  <th className="px-4 py-2.5 text-right">Points</th>
                </tr>
              </thead>
              <tbody>
                {picks.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center text-sm text-ink-500">No picks yet.</td>
                  </tr>
                ) : (
                  picks.map((p) => (
                    <tr key={p.id} className="border-b border-mat-800 last:border-0">
                      <td className="px-4 py-3 font-mono text-xs font-bold text-gold-400">
                        {weightLabel(p.weight_class?.weight ?? p.weight_class?.name)}
                      </td>
                      <td className="px-4 py-3">
                        {p.wrestler ? (
                          <span className="flex items-center gap-2">
                            {p.wrestler.seed != null && (
                              <span className="rounded bg-mat-700 px-1.5 py-0.5 font-mono text-[10px] font-bold text-gold-400">{p.wrestler.seed}</span>
                            )}
                            <span className="truncate font-semibold text-ink-100">{p.wrestler.name}</span>
                            {p.wrestler.school && <span className="text-ink-500">({p.wrestler.school})</span>}
                          </span>
                        ) : (
                          <span className="text-ink-600">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right font-mono text-sm text-ink-400">{p.cost ?? '—'}</td>
                      <td className="px-4 py-3 text-right font-mono text-sm font-bold text-ink-100">{formatPoints(p.points_earned)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </Card>
      </motion.section>
    </motion.div>
  )
}

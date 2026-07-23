import React, { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, ArrowLeft, Check, ExternalLink, RefreshCw, Swords } from 'lucide-react'
import { api } from '../lib/api'
import { toast } from '../lib/store'
import { Button, Card, EmptyState, Select, Skeleton } from '../components/ui'

export default function LeagueLineup() {
  const { id } = useParams()
  const qc = useQueryClient()
  const [weekId, setWeekId] = useState('')
  const [assignments, setAssignments] = useState({}) // season_weight_class_id -> canonical_wrestler_id

  const { data: weeks, isLoading: weeksLoading } = useQuery({
    queryKey: ['league-weeks', id],
    queryFn: () => api.leagueWeeks(id),
  })

  const headToHeadWeeks = useMemo(() => (weeks ?? []).filter((w) => w.week_type === 'head_to_head'), [weeks])

  useEffect(() => {
    if (!weekId && headToHeadWeeks.length) setWeekId(String(headToHeadWeeks[0].id))
  }, [headToHeadWeeks, weekId])

  const { data: weightClasses } = useQuery({
    queryKey: ['league-weight-classes', id],
    queryFn: () => api.leagueWeightClasses(id),
  })

  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['league-lineup', id, weekId],
    queryFn: () => api.leagueLineup(id, Number(weekId)),
    enabled: !!weekId,
  })

  useEffect(() => {
    if (!data) return
    const next = {}
    for (const slot of data.slots ?? []) {
      next[slot.season_weight_class_id] = slot.wrestler?.id
    }
    setAssignments(next)
  }, [data])

  const roster = data?.roster ?? []
  const seasonWeek = data?.season_week
  const locked = seasonWeek && seasonWeek.status !== 'upcoming' && seasonWeek.status !== 'open'

  const saveMutation = useMutation({
    mutationFn: () => {
      const slots = Object.entries(assignments)
        .filter(([, wrestlerId]) => wrestlerId)
        .map(([weightClassId, wrestlerId]) => ({
          season_weight_class_id: Number(weightClassId),
          canonical_wrestler_id: Number(wrestlerId),
        }))
      return api.setLeagueLineup(id, Number(weekId), slots)
    },
    onSuccess: () => {
      toast.success('Lineup saved')
      qc.invalidateQueries({ queryKey: ['league-lineup', id, weekId] })
    },
    onError: (err) => toast.error('Could not save lineup', { body: err.message }),
  })

  const allFilled = (weightClasses ?? []).length > 0 && (weightClasses ?? []).every((wc) => assignments[wc.id])
  // a wrestler can only occupy one slot at a time
  const usedWrestlerIds = new Set(Object.values(assignments).filter(Boolean))

  return (
    <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} className="space-y-6 py-6">
      <Link to={`/leagues/${id}`} className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to league
      </Link>

      <header className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">
          My <span className="text-gold-400">Lineup</span>
        </h1>
        {weeksLoading ? (
          <Skeleton className="h-10 w-48" />
        ) : (
          <Select value={weekId} onChange={(e) => setWeekId(e.target.value)} className="w-56">
            {headToHeadWeeks.length === 0 && <option value="">No head-to-head weeks yet</option>}
            {headToHeadWeeks.map((w) => (
              <option key={w.id} value={w.id}>
                Week {w.week_number}
              </option>
            ))}
          </Select>
        )}
      </header>

      {!weekId ? (
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title="No head-to-head weeks set up yet"
          body="The commissioner needs to seed this season's week timeline first."
        />
      ) : isLoading ? (
        <Skeleton className="h-96 w-full" />
      ) : isError ? (
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title="Could not load your lineup"
          body={error?.message}
          action={
            <Button onClick={() => refetch()} loading={isRefetching}>
              <RefreshCw size={15} /> Try again
            </Button>
          }
        />
      ) : (
        <>
          {locked && (
            <Card className="border-blood-500/40 p-4 text-sm text-blood-400">This week's lineups are locked — you're viewing your final submission.</Card>
          )}
          <Card className="divide-y divide-mat-700 p-0">
            {(weightClasses ?? []).map((wc) => (
              <div key={wc.id} className="flex items-center justify-between gap-3 p-4">
                <div className="w-20 shrink-0 text-sm font-bold text-ink-100">{wc.weight} lbs</div>
                <Select
                  className="flex-1"
                  value={assignments[wc.id] ?? ''}
                  onChange={(e) => setAssignments((a) => ({ ...a, [wc.id]: e.target.value ? Number(e.target.value) : undefined }))}
                  disabled={locked}
                >
                  <option value="">— Empty —</option>
                  {roster.map((r) => {
                    const record = r.record
                    const recordLabel = record && (record.wins > 0 || record.losses > 0) ? ` (${record.wins}-${record.losses})` : ''
                    return (
                      <option
                        key={r.roster_slot_id}
                        value={r.wrestler?.id}
                        disabled={usedWrestlerIds.has(r.wrestler?.id) && assignments[wc.id] !== r.wrestler?.id}
                      >
                        {r.wrestler?.display_name}
                        {recordLabel} {r.slot_type === 'alternate' ? '(alt)' : ''}
                      </option>
                    )
                  })}
                </Select>
              </div>
            ))}
            {(weightClasses ?? []).length === 0 && <p className="p-6 text-center text-sm text-ink-500">No weight classes set up for this season yet.</p>}
          </Card>

          {!locked && (
            <Button size="lg" onClick={() => saveMutation.mutate()} loading={saveMutation.isPending} disabled={!allFilled}>
              <Check size={16} /> Save lineup
            </Button>
          )}
          {!allFilled && !locked && <p className="text-xs text-ink-500">Fill every weight class before saving.</p>}

          {roster.length > 0 && (
            <Card className="divide-y divide-mat-700 p-0">
              <div className="p-4 pb-0 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">My roster</div>
              {roster.map((r) => {
                const record = r.record
                const duals = r.week_duals ?? []
                return (
                  <div key={r.roster_slot_id} className="flex flex-wrap items-center justify-between gap-2 p-4">
                    <div className="min-w-0">
                      <div className="text-sm font-semibold text-ink-100">
                        {r.wrestler?.display_name}
                        {r.slot_type === 'alternate' && <span className="ml-2 text-xs font-normal text-ink-500">alternate</span>}
                      </div>
                      {record && (record.wins > 0 || record.losses > 0) && (
                        <div className="font-mono text-xs text-ink-500">
                          {record.wins}-{record.losses} · {record.falls} pins · {record.tech_falls} tech falls · {record.majors} majors
                        </div>
                      )}
                      {duals.length > 0 ? (
                        <div className="mt-1.5 space-y-0.5">
                          {duals.map((d) => (
                            <div key={d.dual_meet_id}>
                              <div className="flex items-center gap-1.5 text-xs">
                                <Swords size={11} className="shrink-0 text-gold-500/70" />
                                <span className="text-ink-500">{d.is_home ? 'vs' : '@'}</span>
                                <Link to={`/dual-meets/${d.dual_meet_id}`} className="font-semibold text-ink-300 hover:text-gold-400">
                                  {d.opponent_name}
                                </Link>
                                <span className="text-ink-600">
                                  {d.occurred_at ? new Date(d.occurred_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) : ''}
                                </span>
                              </div>
                              {d.projected_opponent && (
                                <div className="ml-[19px] text-[11px] text-ink-600">
                                  Projected: <span className="font-semibold text-ink-400">{d.projected_opponent.display_name}</span>
                                </div>
                              )}
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="mt-1 text-xs text-ink-600">No dual meet on record this week.</div>
                      )}
                    </div>
                    <Link
                      to={`/wrestlers/${r.wrestler?.id}`}
                      target="_blank"
                      rel="noreferrer"
                      className="inline-flex shrink-0 items-center gap-1 text-xs font-semibold text-gold-400 hover:text-gold-300"
                    >
                      Full profile <ExternalLink size={12} />
                    </Link>
                  </div>
                )
              })}
            </Card>
          )}
        </>
      )}
    </motion.div>
  )
}

import React, { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, ArrowLeft, RefreshCw, Swords } from 'lucide-react'
import { api } from '../lib/api'
import { Badge, Button, Card, EmptyState, Select, Skeleton } from '../components/ui'

const RESULT_BADGE = {
  win: { color: 'pin', label: 'Win' },
  loss: { color: 'blood', label: 'Loss' },
  tie: { color: 'ink', label: 'Tie' },
  pending: { color: 'gold', label: 'In progress' },
}

function SlotRow({ mySlot, oppSlot }) {
  const myWon = mySlot && oppSlot && mySlot.points > oppSlot.points
  const oppWon = mySlot && oppSlot && oppSlot.points > mySlot.points

  return (
    <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-2 border-b border-mat-700 px-3 py-2.5 text-sm last:border-b-0">
      <SlotCell slot={mySlot} highlight={myWon} align="right" />
      <div className="w-10 shrink-0 text-center text-ink-700">vs</div>
      <SlotCell slot={oppSlot} highlight={oppWon} align="left" />
    </div>
  )
}

function SlotCell({ slot, highlight, align }) {
  if (!slot) {
    return <div className={`text-xs text-ink-600 ${align === 'right' ? 'text-right' : 'text-left'}`}>— empty —</div>
  }
  const record = slot.record
  return (
    <div className={align === 'right' ? 'text-right' : 'text-left'}>
      <Link to={`/wrestlers/${slot.wrestler?.id}`} className="text-sm font-semibold text-ink-100 hover:text-gold-400">
        {slot.wrestler?.display_name}
      </Link>
      {record && (record.wins > 0 || record.losses > 0) && (
        <div className="font-mono text-[11px] text-ink-500">
          {record.wins}-{record.losses}
          {record.falls > 0 && ` · ${record.falls} pins`}
        </div>
      )}
      <div className={`mt-0.5 flex items-center gap-1.5 text-xs ${align === 'right' ? 'justify-end' : 'justify-start'}`}>
        <span className={`font-mono font-bold ${highlight ? 'text-gold-400' : 'text-ink-300'}`}>{Number(slot.points ?? 0).toFixed(1)}</span>
        {!slot.competed && <span className="text-ink-600">(no match)</span>}
        {slot.medal_bonus > 0 && <span className="text-ink-500">+{slot.medal_bonus} medal</span>}
      </div>
    </div>
  )
}

export default function LeagueMatchup() {
  const { id } = useParams()
  const [weekId, setWeekId] = useState('')

  const { data: weeks, isLoading: weeksLoading } = useQuery({
    queryKey: ['league-weeks', id],
    queryFn: () => api.leagueWeeks(id),
  })

  const headToHeadWeeks = useMemo(() => (weeks ?? []).filter((w) => w.week_type === 'head_to_head'), [weeks])

  useEffect(() => {
    if (!weekId && headToHeadWeeks.length) setWeekId(String(headToHeadWeeks[0].id))
  }, [headToHeadWeeks, weekId])

  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['league-matchup', id, weekId],
    queryFn: () => api.leagueMatchup(id, Number(weekId)),
    enabled: !!weekId,
  })

  const mySlots = data?.me?.slots ?? []
  const oppSlots = data?.opponent?.slots ?? []

  // Pair slots by season_weight_class_id so both columns line up on the same
  // weight even if one side hasn't filled every slot
  const pairedRows = useMemo(() => {
    const weightClassIds = new Set([...mySlots.map((s) => s.season_weight_class_id), ...oppSlots.map((s) => s.season_weight_class_id)])
    return [...weightClassIds].map((wcId) => ({
      wcId,
      mySlot: mySlots.find((s) => s.season_weight_class_id === wcId),
      oppSlot: oppSlots.find((s) => s.season_weight_class_id === wcId),
    }))
  }, [mySlots, oppSlots])

  const result = data?.matchup?.my_result
  const resultBadge = RESULT_BADGE[result] ?? RESULT_BADGE.pending

  return (
    <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} className="space-y-6 py-6">
      <Link to={`/leagues/${id}`} className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to league
      </Link>

      <header className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">
          <Swords className="mr-2 inline text-gold-400" size={22} />
          Matchup
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
        <EmptyState icon={<AlertTriangle size={26} />} title="No head-to-head weeks set up yet" body="The commissioner needs to seed this season's week timeline first." />
      ) : isLoading ? (
        <Skeleton className="h-96 w-full" />
      ) : isError ? (
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title={error?.status === 404 ? "You don't have a matchup this week" : 'Could not load this matchup'}
          body={error?.status === 404 ? "Byes, or a week that hasn't been paired up yet, will show this." : error?.message}
          action={
            error?.status !== 404 && (
              <Button onClick={() => refetch()} loading={isRefetching}>
                <RefreshCw size={15} /> Try again
              </Button>
            )
          }
        />
      ) : (
        <>
          <Card className="flex flex-wrap items-center justify-between gap-3 p-4">
            <div className="flex-1 text-right">
              <div className="text-sm font-bold text-ink-100">Me</div>
              <div className="font-mono text-2xl font-bold text-gold-400">{Number(data?.me?.points ?? 0).toFixed(1)}</div>
            </div>
            <Badge color={resultBadge.color}>{resultBadge.label}</Badge>
            <div className="flex-1 text-left">
              <div className="text-sm font-bold text-ink-100">{data?.opponent?.user?.display_name || data?.opponent?.user?.username || 'Opponent'}</div>
              <div className="font-mono text-2xl font-bold text-gold-400">{Number(data?.opponent?.points ?? 0).toFixed(1)}</div>
            </div>
          </Card>

          <Card className="divide-y divide-mat-700 p-0">
            {pairedRows.length === 0 ? (
              <p className="p-6 text-center text-sm text-ink-500">Neither side has set a lineup for this week yet.</p>
            ) : (
              pairedRows.map((row) => <SlotRow key={row.wcId} mySlot={row.mySlot} oppSlot={row.oppSlot} />)
            )}
          </Card>
        </>
      )}
    </motion.div>
  )
}

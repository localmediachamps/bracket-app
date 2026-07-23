import React, { useMemo, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, List, Grid3x3, Layers, Trophy } from 'lucide-react'
import { api } from '../lib/api'
import { CardSkeleton, EmptyState } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { ListView, MonthView, groupByDate } from '../components/calendar/CalendarViews'
import { cn } from '../lib/utils'

function eventPath(e) {
  if (e.week_type === 'marquee_tournament' && e.tournament_slug) return `/tournaments/${e.tournament_slug}`
  return `/leagues/${e.league_id}/matchup`
}

function eventIcon(e) {
  return e.week_type === 'marquee_tournament' ? Trophy : Layers
}

export default function LeagueCalendar() {
  const { id } = useParams()
  const [view, setView] = useState('list')
  const [monthCursor, setMonthCursor] = useState(() => {
    const d = new Date()
    return new Date(d.getFullYear(), d.getMonth(), 1)
  })

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['league-calendar', id],
    queryFn: () => api.leagueCalendar(id),
  })

  const events = data?.events ?? []
  const byDate = useMemo(() => groupByDate(events), [events])
  const sortedDates = useMemo(() => [...byDate.keys()].sort(), [byDate])

  if (isLoading) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-8">
        <CardSkeleton />
      </div>
    )
  }

  if (isError) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-8">
        <ErrorState error={error} onRetry={refetch} title="Couldn't load the league calendar" />
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <Link to={`/leagues/${id}`} className="mb-5 inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to {data?.league?.name ?? 'League'}
      </Link>

      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <h1 className="font-display text-2xl uppercase tracking-wide text-ink-100">Season Calendar</h1>
        <div className="flex rounded-lg border border-mat-700 p-0.5">
          <button
            onClick={() => setView('list')}
            className={cn('flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-bold', view === 'list' ? 'bg-mat-800 text-gold-400' : 'text-ink-500 hover:text-ink-200')}
          >
            <List size={14} /> List
          </button>
          <button
            onClick={() => setView('month')}
            className={cn('flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-bold', view === 'month' ? 'bg-mat-800 text-gold-400' : 'text-ink-500 hover:text-ink-200')}
          >
            <Grid3x3 size={14} /> Month
          </button>
        </div>
      </div>

      {events.length === 0 ? (
        <EmptyState icon={<Layers size={22} />} title="No weeks scheduled yet" body="Once the commissioner sets up the season timeline, weeks will show up here." />
      ) : view === 'list' ? (
        <ListView dates={sortedDates} byDate={byDate} eventIcon={eventIcon} eventPath={eventPath} />
      ) : (
        <MonthView cursor={monthCursor} setCursor={setMonthCursor} byDate={byDate} eventIcon={eventIcon} eventPath={eventPath} />
      )}
    </div>
  )
}

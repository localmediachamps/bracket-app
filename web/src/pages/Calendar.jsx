import React, { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, List, Grid3x3, Trophy, Swords, CheckCircle2 } from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore } from '../lib/store'
import { Badge, Card, CardSkeleton, EmptyState } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { cn } from '../lib/utils'

const STATUS_COLOR = {
  open: 'pin',
  live: 'pin',
  locked: 'ink',
  scoring: 'ink',
  completed: 'ink',
  draft: 'ink',
  cancelled: 'blood',
}

function eventPath(e) {
  return e.type === 'dual_meet' ? `/dual-meets/${e.id}` : `/tournaments/${e.slug}`
}

function parseYmd(s) {
  if (!s) return null
  const [y, m, d] = s.split('-').map(Number)
  return new Date(y, m - 1, d)
}

function monthLabel(date) {
  return date.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })
}

export default function CalendarPage() {
  const token = useAuthStore((s) => s.token)
  const [view, setView] = useState('list')
  const [monthCursor, setMonthCursor] = useState(() => {
    const d = new Date()
    return new Date(d.getFullYear(), d.getMonth(), 1)
  })

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['calendar'],
    queryFn: api.calendar,
    staleTime: 60000,
  })

  const { data: subsData } = useQuery({
    queryKey: ['calendar-submissions'],
    queryFn: api.calendarMySubmissions,
    enabled: !!token,
    staleTime: 30000,
  })

  const submittedSet = useMemo(() => {
    const s = new Set()
    ;(subsData?.tournament_ids ?? []).forEach((id) => s.add(`tournament-${id}`))
    ;(subsData?.dual_meet_ids ?? []).forEach((id) => s.add(`dual_meet-${id}`))
    return s
  }, [subsData])

  const events = data?.events ?? []
  const hasSubmitted = (e) => submittedSet.has(`${e.type}-${e.id}`)

  // Group by date (YYYY-MM-DD) for both the list view's section headers and
  // the month grid's per-day cells.
  const byDate = useMemo(() => {
    const map = new Map()
    for (const e of events) {
      if (!e.start_date) continue
      if (!map.has(e.start_date)) map.set(e.start_date, [])
      map.get(e.start_date).push(e)
    }
    return map
  }, [events])

  const sortedDates = useMemo(() => [...byDate.keys()].sort(), [byDate])

  if (isLoading) {
    return (
      <div>
        <CardSkeleton />
      </div>
    )
  }

  if (isError) return <ErrorState error={error} onRetry={refetch} title="Couldn't load the calendar" />

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="font-display text-2xl uppercase tracking-wide text-ink-100">Competition Calendar</h1>
          <p className="mt-1 text-sm text-ink-500">Every tournament and dual meet on the platform, in one place.</p>
        </div>
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
        <EmptyState icon={<Trophy size={22} />} title="Nothing on the calendar yet" body="Tournaments and dual meets will show up here once they're created." />
      ) : view === 'list' ? (
        <ListView dates={sortedDates} byDate={byDate} hasSubmitted={hasSubmitted} />
      ) : (
        <MonthView cursor={monthCursor} setCursor={setMonthCursor} byDate={byDate} hasSubmitted={hasSubmitted} />
      )}
    </div>
  )
}

function EventRow({ e, submitted }) {
  const Icon = e.type === 'dual_meet' ? Swords : Trophy
  return (
    <Link to={eventPath(e)} className="flex items-center gap-3 px-4 py-3 hover:bg-mat-800/50">
      <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-mat-800 text-gold-500">
        <Icon size={14} />
      </span>
      <span className="min-w-0 flex-1 truncate text-sm font-semibold text-ink-100">{e.name}</span>
      {submitted && (
        <span className="flex shrink-0 items-center gap-1 text-[10px] font-bold uppercase text-pin-400">
          <CheckCircle2 size={12} /> Submitted
        </span>
      )}
      <Badge color={STATUS_COLOR[e.status] ?? 'ink'} className="shrink-0">{e.status}</Badge>
    </Link>
  )
}

function ListView({ dates, byDate, hasSubmitted }) {
  if (dates.length === 0) {
    return <EmptyState icon={<Trophy size={22} />} title="No dated events" body="Events without a date won't appear in this view." />
  }
  return (
    <div className="space-y-5">
      {dates.map((d) => (
        <div key={d}>
          <h2 className="mb-2 text-xs font-bold uppercase tracking-wider text-ink-500">
            {parseYmd(d).toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}
          </h2>
          <Card className="divide-y divide-mat-700/60 overflow-hidden p-0">
            {byDate.get(d).map((e) => (
              <EventRow key={`${e.type}-${e.id}`} e={e} submitted={hasSubmitted(e)} />
            ))}
          </Card>
        </div>
      ))}
    </div>
  )
}

function MonthView({ cursor, setCursor, byDate, hasSubmitted }) {
  const year = cursor.getFullYear()
  const month = cursor.getMonth()
  const firstOfMonth = new Date(year, month, 1)
  const startWeekday = firstOfMonth.getDay()
  const daysInMonth = new Date(year, month + 1, 0).getDate()
  const today = new Date()
  const todayKey = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

  const cells = []
  for (let i = 0; i < startWeekday; i++) cells.push(null)
  for (let day = 1; day <= daysInMonth; day++) cells.push(day)

  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <button onClick={() => setCursor(new Date(year, month - 1, 1))} className="rounded-lg p-2 text-ink-400 hover:bg-mat-850 hover:text-ink-100">
          <ChevronLeft size={17} />
        </button>
        <h2 className="text-sm font-bold uppercase tracking-wide text-ink-100">{monthLabel(cursor)}</h2>
        <button onClick={() => setCursor(new Date(year, month + 1, 1))} className="rounded-lg p-2 text-ink-400 hover:bg-mat-850 hover:text-ink-100">
          <ChevronRight size={17} />
        </button>
      </div>

      <div className="grid grid-cols-7 gap-1.5 text-center text-[10px] font-bold uppercase tracking-wider text-ink-600">
        {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((d) => <div key={d}>{d}</div>)}
      </div>
      <div className="mt-1.5 grid grid-cols-7 gap-1.5">
        {cells.map((day, i) => {
          if (day == null) return <div key={`blank-${i}`} />
          const key = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
          const dayEvents = byDate.get(key) ?? []
          const isToday = key === todayKey
          return (
            <div
              key={key}
              className={cn(
                'min-h-[84px] rounded-lg border p-1.5 text-left',
                isToday ? 'border-gold-500/50 bg-gold-500/[0.04]' : 'border-mat-700/60'
              )}
            >
              <div className={cn('mb-1 text-[11px] font-bold', isToday ? 'text-gold-400' : 'text-ink-500')}>{day}</div>
              <div className="space-y-1">
                {dayEvents.slice(0, 3).map((e) => {
                  const Icon = e.type === 'dual_meet' ? Swords : Trophy
                  return (
                    <Link
                      key={`${e.type}-${e.id}`}
                      to={eventPath(e)}
                      className="flex items-center gap-1 truncate rounded px-1 py-0.5 text-[10px] font-semibold text-ink-200 hover:bg-mat-800"
                      title={e.name}
                    >
                      <Icon size={9} className="shrink-0 text-gold-500" />
                      <span className="truncate">{e.name}</span>
                    </Link>
                  )
                })}
                {dayEvents.length > 3 && (
                  <div className="px-1 text-[10px] text-ink-600">+{dayEvents.length - 3} more</div>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

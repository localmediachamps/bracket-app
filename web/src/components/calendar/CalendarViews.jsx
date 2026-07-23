import React from 'react'
import { Link } from 'react-router-dom'
import { ChevronLeft, ChevronRight, Trophy, CheckCircle2 } from 'lucide-react'
import { Badge, Card, EmptyState } from '../ui'
import { cn } from '../../lib/utils'

export const STATUS_COLOR = {
  open: 'pin',
  live: 'pin',
  locked: 'ink',
  scoring: 'ink',
  completed: 'ink',
  draft: 'ink',
  upcoming: 'ink',
  complete: 'ink',
  cancelled: 'blood',
}

export function parseYmd(s) {
  if (!s) return null
  const [y, m, d] = s.split('-').map(Number)
  return new Date(y, m - 1, d)
}

export function monthLabel(date) {
  return date.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })
}

// Shared by the global Competition Calendar and the per-league calendar -
// both feed {type, id, name, start_date, status} shaped events, differing
// only in what icon to show and where a click should navigate (eventIcon/
// eventPath are injected rather than hardcoded here).
export function ListView({ dates, byDate, hasSubmitted, eventIcon, eventPath, emptyBody }) {
  if (dates.length === 0) {
    return <EmptyState icon={<Trophy size={22} />} title="No dated events" body={emptyBody ?? "Events without a date won't appear in this view."} />
  }
  return (
    <div className="space-y-5">
      {dates.map((d) => (
        <div key={d}>
          <h2 className="mb-2 text-xs font-bold uppercase tracking-wider text-ink-500">
            {parseYmd(d).toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}
          </h2>
          <Card className="divide-y divide-mat-700/60 overflow-hidden p-0">
            {byDate.get(d).map((e) => {
              const Icon = eventIcon(e)
              const submitted = hasSubmitted?.(e)
              return (
                <Link key={`${e.type}-${e.id}`} to={eventPath(e)} className="flex items-center gap-3 px-4 py-3 hover:bg-mat-800/50">
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
            })}
          </Card>
        </div>
      ))}
    </div>
  )
}

export function MonthView({ cursor, setCursor, byDate, eventIcon, eventPath }) {
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
                  const Icon = eventIcon(e)
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

export function groupByDate(events) {
  const byDate = new Map()
  for (const e of events) {
    if (!e.start_date) continue
    if (!byDate.has(e.start_date)) byDate.set(e.start_date, [])
    byDate.get(e.start_date).push(e)
  }
  return byDate
}

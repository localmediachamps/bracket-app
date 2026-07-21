import React, { useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, Building2, Calendar, Users } from 'lucide-react'
import { api } from '../lib/api'
import { Card, CardSkeleton, EmptyState } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { cn } from '../lib/utils'

export default function TeamProfile() {
  const { id } = useParams()

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['team-profile', id],
    queryFn: () => api.teamProfile(id),
  })

  const [activeSeason, setActiveSeason] = useState(null)

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
        <ErrorState error={error} onRetry={refetch} title="Couldn't load this team" />
      </div>
    )
  }

  const { team, roster, schedule } = data
  const season = activeSeason ?? roster[0]?.season_label
  const rosterForSeason = roster.find((r) => r.season_label === season)

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <Link to="/teams" className="mb-5 inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to Teams
      </Link>

      <div className="mb-6 flex items-center gap-3">
        <span className="flex h-14 w-14 items-center justify-center rounded-2xl bg-mat-800 text-gold-500">
          <Building2 size={26} />
        </span>
        <div>
          <h1 className="font-display text-2xl text-ink-50">{team.name}</h1>
          {team.conference && <p className="text-sm text-ink-400">{team.conference}</p>}
        </div>
      </div>

      <Card className="mb-6 p-5">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-[11px] font-bold uppercase tracking-[0.14em] text-ink-500">Roster</h2>
          {roster.length > 1 && (
            <div className="flex flex-wrap gap-1.5">
              {roster.map((r) => (
                <button
                  key={r.season_label}
                  type="button"
                  onClick={() => setActiveSeason(r.season_label)}
                  className={cn(
                    'rounded-full border px-2.5 py-1 text-[11px] font-bold',
                    season === r.season_label
                      ? 'border-gold-500/60 bg-gold-500/10 text-gold-400'
                      : 'border-mat-700 text-ink-500 hover:text-ink-200'
                  )}
                >
                  {r.season_label}
                </button>
              ))}
            </div>
          )}
        </div>
        {rosterForSeason?.wrestlers.length ? (
          <div className="grid grid-cols-1 gap-1.5 sm:grid-cols-2">
            {rosterForSeason.wrestlers
              .slice()
              .sort((a, b) => a.display_name.localeCompare(b.display_name))
              .map((w) => (
                <Link
                  key={w.wrestler_id}
                  to={`/wrestlers/${w.wrestler_id}`}
                  className="flex items-center justify-between gap-2 rounded-lg px-2.5 py-1.5 text-sm hover:bg-mat-800"
                >
                  <span className="font-semibold text-ink-100">{w.display_name}</span>
                  <span className="text-xs text-ink-500">{w.match_count} matches</span>
                </Link>
              ))}
          </div>
        ) : (
          <EmptyState icon={<Users size={22} />} title="No roster on record" body="No linked wrestlers for this season yet." />
        )}
      </Card>

      <Card className="p-5">
        <h2 className="mb-3 text-[11px] font-bold uppercase tracking-[0.14em] text-ink-500">Schedule</h2>
        {schedule.length ? (
          <div className="space-y-2">
            {schedule.map((ev, i) => (
              <div key={i} className="text-sm text-ink-300">{ev.name}</div>
            ))}
          </div>
        ) : (
          <EmptyState
            icon={<Calendar size={22} />}
            title="Schedule not available yet"
            body="This team's upcoming schedule hasn't been added yet."
          />
        )}
      </Card>
    </div>
  )
}

import React, { useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, Building2, Calendar, Users, ExternalLink } from 'lucide-react'
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
  const scheduleForSeason = schedule.find((s) => s.season_label === season)

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <Link to="/teams" className="mb-5 inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to Teams
      </Link>

      <div className="mb-6 flex items-center gap-3">
        <span className={cn('flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl', team.logo_url ? 'bg-white p-2' : 'bg-mat-800 text-gold-500')}>
          {team.logo_url ? (
            <img src={team.logo_url} alt="" className="h-full w-full object-contain" />
          ) : (
            <Building2 size={26} />
          )}
        </span>
        <div>
          <h1 className="font-display text-2xl text-ink-50">{team.name}</h1>
          {team.conference && <p className="text-sm text-ink-400">{team.conference}</p>}
        </div>
        <div className="ml-auto flex flex-wrap items-center gap-2">
          {team.roster_url && (
            <a
              href={team.roster_url}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1.5 rounded-lg border border-mat-700 px-3 py-1.5 text-xs font-bold text-ink-400 hover:border-gold-500/50 hover:text-gold-400"
            >
              Official Roster <ExternalLink size={13} />
            </a>
          )}
          {team.schedule_url && (
            <a
              href={team.schedule_url}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1.5 rounded-lg border border-mat-700 px-3 py-1.5 text-xs font-bold text-ink-400 hover:border-gold-500/50 hover:text-gold-400"
            >
              Official Schedule <ExternalLink size={13} />
            </a>
          )}
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
          // Already sorted by weight class (ascending) by the backend -
          // keep that order rather than re-sorting alphabetically here.
          <div className="grid grid-cols-1 gap-1.5 sm:grid-cols-2">
            {rosterForSeason.wrestlers.map((w) => (
              <Link
                key={w.wrestler_id}
                to={`/wrestlers/${w.wrestler_id}`}
                className="flex items-center gap-2.5 rounded-lg px-2.5 py-1.5 text-sm hover:bg-mat-800"
              >
                <span className="w-9 shrink-0 font-mono text-xs font-bold text-gold-500">{w.weight_class || '—'}</span>
                <span className="min-w-0 flex-1 truncate font-semibold text-ink-100">{w.display_name}</span>
                {w.career_wins != null ? (
                  <span className="shrink-0 text-right font-mono text-xs font-bold text-ink-300">
                    <span className="block">{w.wins}-{w.losses} <span className="text-ink-600">szn</span></span>
                    <span className="block text-ink-500">{w.career_wins}-{w.career_losses} <span className="text-ink-600">career</span></span>
                  </span>
                ) : (
                  <span className="shrink-0 font-mono text-xs font-bold text-ink-300">
                    {w.wins != null ? `${w.wins}-${w.losses}` : `${w.match_count} matches`}
                  </span>
                )}
              </Link>
            ))}
          </div>
        ) : (
          <EmptyState icon={<Users size={22} />} title="No roster on record" body="No linked wrestlers for this season yet." />
        )}
      </Card>

      <Card className="p-5">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-[11px] font-bold uppercase tracking-[0.14em] text-ink-500">Dual meet schedule</h2>
          {schedule.length > 1 && (
            <div className="flex flex-wrap gap-1.5">
              {schedule.map((s) => (
                <button
                  key={s.season_label}
                  type="button"
                  onClick={() => setActiveSeason(s.season_label)}
                  className={cn(
                    'rounded-full border px-2.5 py-1 text-[11px] font-bold',
                    season === s.season_label
                      ? 'border-gold-500/60 bg-gold-500/10 text-gold-400'
                      : 'border-mat-700 text-ink-500 hover:text-ink-200'
                  )}
                >
                  {s.season_label}
                </button>
              ))}
            </div>
          )}
        </div>
        {scheduleForSeason?.duals.length ? (
          <div className="space-y-1">
            {scheduleForSeason.duals.map((d) => (
              <div key={d.dual_meet_id} className="flex items-center gap-3 rounded-lg px-2.5 py-1.5 text-sm hover:bg-mat-800">
                <Link to={`/dual-meets/${d.dual_meet_id}`} className="w-16 shrink-0 font-mono text-[11px] text-ink-500 hover:text-gold-400">
                  {d.occurred_at ? new Date(d.occurred_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) : '—'}
                </Link>
                <span className="w-10 shrink-0 text-[10px] font-bold uppercase text-ink-600">{d.is_home ? 'vs' : '@'}</span>
                <Link to={`/teams/${d.opponent_team_id}`} className="min-w-0 flex-1 truncate font-semibold text-ink-100 hover:text-gold-400">
                  {d.opponent_name}
                </Link>
                <Link to={`/dual-meets/${d.dual_meet_id}`} className="shrink-0 font-mono text-xs font-bold text-ink-300 hover:text-gold-400">
                  {d.own_score != null && d.opp_score != null ? `${d.own_score}-${d.opp_score}` : '—'}
                </Link>
                <span
                  className={cn(
                    'w-9 shrink-0 rounded px-1.5 py-0.5 text-center text-[10px] font-bold uppercase',
                    d.result === 'win' ? 'bg-pin-500/15 text-pin-400' : d.result === 'loss' ? 'bg-blood-500/15 text-blood-400' : 'bg-mat-700 text-ink-500'
                  )}
                >
                  {d.result === 'win' ? 'W' : d.result === 'loss' ? 'L' : d.result === 'tie' ? 'T' : '—'}
                </span>
              </div>
            ))}
          </div>
        ) : (
          <EmptyState
            icon={<Calendar size={22} />}
            title="No dual meets on record"
            body="No reconciled dual-meet results for this season yet."
          />
        )}
      </Card>
    </div>
  )
}

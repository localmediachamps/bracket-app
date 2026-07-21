import React from 'react'
import { useParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, User, Trophy, Zap, Flame, TrendingUp } from 'lucide-react'
import { api } from '../lib/api'
import { Badge, Card, CardSkeleton, EmptyState, Stat } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { cn, victoryLabel } from '../lib/utils'

// Same victory-type styling convention as Results.jsx - kept local rather
// than shared since it's a handful of small pure functions, not worth a
// cross-file abstraction yet.
const VICTORY_STYLE = {
  fall: { color: 'blood', icon: Zap },
  tech_fall: { color: 'gold', icon: Flame },
  major: { color: 'gold', icon: TrendingUp },
}
function normalizeVictoryType(raw) {
  if (!raw) return null
  const s = raw.toLowerCase()
  if (s.includes('technical')) return 'tech_fall'
  if (s.includes('major')) return 'major'
  if (s.includes('fall')) return 'fall'
  return null
}
function victoryStyle(victoryType) {
  return VICTORY_STYLE[normalizeVictoryType(victoryType)] || { color: 'ink', icon: null }
}

function placementInfo(roundLabel) {
  if (!roundLabel) return null
  const m = /(\d+)(st|nd|rd|th)\s*Place Match/i.exec(roundLabel)
  if (!m) return null
  return { label: `${m[1]}${m[2].toUpperCase()} PLACE`, isChampionship: m[1] === '1' }
}

function formatDate(occurredAt) {
  if (!occurredAt) return '—'
  return new Date(occurredAt).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

function formatMatchTime(seconds) {
  if (seconds == null) return null
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}:${String(s).padStart(2, '0')}`
}

export default function WrestlerProfile() {
  const { id } = useParams()

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['wrestler-profile', id],
    queryFn: () => api.wrestlerProfile(id),
  })

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
        <ErrorState error={error} onRetry={refetch} title="Couldn't load this wrestler" />
      </div>
    )
  }

  const { wrestler, team_history: teamHistory, overall_record: record, season_records: seasonRecords, matches } = data
  const winPct = record.wins + record.losses > 0 ? Math.round((100 * record.wins) / (record.wins + record.losses)) : null

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <Link to="/results" className="mb-5 inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to Results
      </Link>

      <div className="mb-6 flex flex-wrap items-center gap-3">
        <span className="flex h-14 w-14 items-center justify-center rounded-2xl bg-mat-800 text-gold-500">
          <User size={26} />
        </span>
        <div>
          <h1 className="font-display text-2xl text-ink-50">{wrestler.display_name}</h1>
          {wrestler.current_team && (
            <p className="text-sm text-ink-400">{wrestler.current_team.name}</p>
          )}
        </div>
      </div>

      <div className="mb-6 grid grid-cols-3 gap-3">
        <Stat label="Record" value={`${record.wins}-${record.losses}`} />
        <Stat label="Win %" value={winPct != null ? `${winPct}%` : '—'} />
        <Stat label="Seasons" value={teamHistory.length} />
      </div>

      {teamHistory.length > 0 && (
        <Card className="mb-6 p-5">
          <h2 className="mb-3 text-[11px] font-bold uppercase tracking-[0.14em] text-ink-500">Team History</h2>
          <div className="space-y-2">
            {teamHistory.map((t) => (
              <div key={`${t.team_id}-${t.season_label}`} className="flex items-center justify-between gap-2 text-sm">
                <span className="flex items-center gap-2">
                  <span className="font-mono text-[10px] text-ink-600">{t.season_label}</span>
                  <span className="font-semibold text-ink-100">{t.team_name}</span>
                </span>
                <span className="text-xs text-ink-500">{t.match_count} matches</span>
              </div>
            ))}
          </div>
        </Card>
      )}

      {seasonRecords.length > 0 && (
        <Card className="mb-6 p-5">
          <h2 className="mb-3 text-[11px] font-bold uppercase tracking-[0.14em] text-ink-500">Season Records</h2>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {seasonRecords.map((s) => (
              <div key={s.season_label} className="rounded-lg border border-mat-700 bg-mat-900/50 px-3 py-2 text-center">
                <div className="font-mono text-[10px] text-ink-600">{s.season_label}</div>
                <div className="mt-0.5 font-mono text-lg font-bold text-ink-100">{s.wins}-{s.losses}</div>
              </div>
            ))}
          </div>
        </Card>
      )}

      <Card className="p-5">
        <h2 className="mb-3 text-[11px] font-bold uppercase tracking-[0.14em] text-ink-500">Match History</h2>
        {matches.length === 0 ? (
          <EmptyState icon={<Trophy size={22} />} title="No matches on record" body="This wrestler doesn't have any results linked yet." />
        ) : (
          <div className="divide-y divide-mat-700">
            {matches.map((m) => {
              const { color, icon: Icon } = victoryStyle(m.victory_type)
              const placement = placementInfo(m.round_label)
              const time = formatMatchTime(m.time_seconds)
              return (
                <div key={m.id} className="flex flex-wrap items-center justify-between gap-2 py-3">
                  <div>
                    <div className="flex items-center gap-2 text-sm">
                      <span className={cn('font-bold', m.is_winner ? 'text-pin-400' : 'text-ink-500 line-through decoration-blood-500/60')}>
                        {m.is_winner ? 'W' : 'L'}
                      </span>
                      <span className="text-ink-100">vs {m.opponent_name || 'opponent'}</span>
                      {m.opponent_school && <span className="text-ink-500">({m.opponent_school})</span>}
                    </div>
                    <div className="mt-1 flex flex-wrap items-center gap-1.5">
                      <Badge color={color}>
                        {Icon && <Icon size={11} />} {victoryLabel(m.victory_type) || m.victory_type || '—'}
                      </Badge>
                      {m.score && <span className="font-mono text-[11px] text-ink-500">{m.score}{time ? ` @ ${time}` : ''}</span>}
                      {placement && (
                        <Badge color="gold" className={placement.isChampionship ? 'shadow-glow-sm' : ''}>
                          <Trophy size={11} /> {placement.label}
                        </Badge>
                      )}
                      {m.weight_class && <Badge color="ink">{m.weight_class} lbs</Badge>}
                    </div>
                    <div className="mt-1 text-xs text-ink-600">{m.event_name}</div>
                  </div>
                  <span className="shrink-0 text-xs text-ink-500">{formatDate(m.occurred_at)}</span>
                </div>
              )
            })}
          </div>
        )}
      </Card>
    </div>
  )
}

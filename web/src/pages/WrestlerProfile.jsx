import React, { useMemo, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, User, Trophy, Zap, Flame, TrendingUp, Timer, ExternalLink, Search, X } from 'lucide-react'
import { api } from '../lib/api'
import { Badge, Card, CardSkeleton, EmptyState, Stat } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { cn, classifyRawVictoryType, rawVictoryLabel, rawVictoryColor } from '../lib/utils'

const VICTORY_ICON = { fall: Zap, tech_fall: Flame, major: TrendingUp, sudden_victory: Timer }
function victoryStyle(victoryType) {
  return { color: rawVictoryColor(victoryType), icon: VICTORY_ICON[classifyRawVictoryType(victoryType)] || null }
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
  const [seasonFilter, setSeasonFilter] = useState(null)
  const [resultFilter, setResultFilter] = useState('all') // all | win | loss
  const [opponentQuery, setOpponentQuery] = useState('')

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['wrestler-profile', id],
    queryFn: () => api.wrestlerProfile(id),
  })

  const matches = data?.matches ?? []
  const opponentQueryLower = opponentQuery.trim().toLowerCase()
  const filteredMatches = useMemo(() => {
    return matches.filter((m) => {
      if (seasonFilter && m.season_label !== seasonFilter) return false
      if (resultFilter === 'win' && !m.is_winner) return false
      if (resultFilter === 'loss' && m.is_winner) return false
      if (opponentQueryLower && !(m.opponent_name || '').toLowerCase().includes(opponentQueryLower)) return false
      return true
    })
  }, [matches, seasonFilter, resultFilter, opponentQueryLower])

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

  const { wrestler, team_history: teamHistory, overall_record: record, season_records: seasonRecords } = data
  const winPct = record.wins + record.losses > 0 ? Math.round((100 * record.wins) / (record.wins + record.losses)) : null

  const activeFilterCount = (seasonFilter ? 1 : 0) + (resultFilter !== 'all' ? 1 : 0) + (opponentQueryLower ? 1 : 0)
  const clearFilters = () => { setSeasonFilter(null); setResultFilter('all'); setOpponentQuery('') }

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
        {wrestler.profile_url && (
          <a
            href={wrestler.profile_url}
            target="_blank"
            rel="noreferrer"
            className="ml-auto inline-flex items-center gap-1.5 rounded-lg border border-mat-700 px-3 py-1.5 text-xs font-bold text-ink-400 hover:border-gold-500/50 hover:text-gold-400"
          >
            Official Bio <ExternalLink size={13} />
          </a>
        )}
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
          <h2 className="mb-3 text-[11px] font-bold uppercase tracking-[0.14em] text-ink-500">
            Season Records <span className="normal-case text-ink-600">— click to filter match history below</span>
          </h2>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {seasonRecords.map((s) => {
              const active = seasonFilter === s.season_label
              return (
                <button
                  key={s.season_label}
                  onClick={() => setSeasonFilter(active ? null : s.season_label)}
                  className={cn(
                    'rounded-lg border px-3 py-2 text-center transition-colors',
                    active ? 'border-gold-500 bg-gold-500/10' : 'border-mat-700 bg-mat-900/50 hover:border-mat-500'
                  )}
                >
                  <div className={cn('font-mono text-[10px]', active ? 'text-gold-400' : 'text-ink-600')}>{s.season_label}</div>
                  <div className="mt-0.5 font-mono text-lg font-bold text-ink-100">{s.wins}-{s.losses}</div>
                </button>
              )
            })}
          </div>
        </Card>
      )}

      <Card className="p-5">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-[11px] font-bold uppercase tracking-[0.14em] text-ink-500">Match History</h2>
          {activeFilterCount > 0 && (
            <button onClick={clearFilters} className="flex items-center gap-1 text-xs font-semibold text-ink-500 hover:text-ink-200">
              <X size={12} /> Clear filters ({activeFilterCount})
            </button>
          )}
        </div>

        {matches.length > 0 && (
          <div className="mb-4 flex flex-wrap items-center gap-2">
            <div className="flex rounded-lg border border-mat-700 p-0.5">
              {[
                { key: 'all', label: 'All' },
                { key: 'win', label: 'Wins' },
                { key: 'loss', label: 'Losses' },
              ].map((opt) => (
                <button
                  key={opt.key}
                  onClick={() => setResultFilter(opt.key)}
                  className={cn(
                    'rounded-md px-3 py-1.5 text-xs font-bold transition-colors',
                    resultFilter === opt.key ? 'bg-mat-800 text-gold-400' : 'text-ink-500 hover:text-ink-200'
                  )}
                >
                  {opt.label}
                </button>
              ))}
            </div>
            <div className="relative flex-1 min-w-[180px]">
              <Search size={13} className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-ink-500" />
              <input
                value={opponentQuery}
                onChange={(e) => setOpponentQuery(e.target.value)}
                placeholder="Search opponent…"
                className="w-full rounded-lg border border-mat-700 bg-mat-850 py-1.5 pl-8 pr-3 text-xs text-ink-100 placeholder:text-ink-600 focus:border-gold-500/50 focus:outline-none"
              />
            </div>
            {seasonFilter && (
              <Badge color="gold">{seasonFilter}</Badge>
            )}
          </div>
        )}

        {matches.length === 0 ? (
          <EmptyState icon={<Trophy size={22} />} title="No matches on record" body="This wrestler doesn't have any results linked yet." />
        ) : filteredMatches.length === 0 ? (
          <EmptyState icon={<Search size={20} />} title="No matches found" body="Try clearing a filter." />
        ) : (
          <div className="divide-y divide-mat-700">
            {filteredMatches.map((m) => {
              const { color, icon: Icon } = victoryStyle(m.victory_type)
              const placement = placementInfo(m.round_label)
              const time = formatMatchTime(m.time_seconds)
              return (
                <div key={m.id} className="py-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="flex min-w-0 items-center gap-2 text-sm">
                      <span className={cn('shrink-0 font-bold', m.is_winner ? 'text-pin-400' : 'text-ink-500')}>
                        {m.is_winner ? 'W' : 'L'}
                      </span>
                      <span className="truncate text-ink-100">vs {m.opponent_name || 'opponent'}</span>
                      {m.opponent_school && <span className="shrink-0 text-ink-500">({m.opponent_school})</span>}
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="inline-flex items-center gap-2 rounded-md border border-mat-700 bg-mat-900/60 px-2 py-1">
                        <Badge color={color}>
                          {Icon && <Icon size={11} />} {rawVictoryLabel(m.victory_type) || '—'}
                        </Badge>
                        {(m.score || time) && (
                          <span className="font-mono text-sm font-bold text-ink-100">
                            {m.score}{m.score && time && ' '}{time && `@ ${time}`}
                          </span>
                        )}
                      </span>
                      {placement && (
                        <Badge color="gold" className={placement.isChampionship ? 'shadow-glow-sm' : ''}>
                          <Trophy size={11} /> {placement.label}
                        </Badge>
                      )}
                      {m.weight_class && <Badge color="ink">{m.weight_class} lbs</Badge>}
                    </div>
                  </div>
                  <div className="mt-1.5 flex items-center justify-between gap-2 text-xs text-ink-600">
                    <span>
                      {m.event_name}
                      {m.round_label && !placement && <span> · {m.round_label}</span>}
                    </span>
                    <span className="shrink-0 text-ink-500">{formatDate(m.occurred_at)}</span>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </Card>
    </div>
  )
}

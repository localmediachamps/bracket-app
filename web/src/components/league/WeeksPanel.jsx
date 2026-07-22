import React, { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Settings } from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Badge, Button, Card, Select } from '../ui'

const MODE_LABEL = {
  bracket: 'Bracket challenge (full field)',
  pickem: "Pick'em (full field)",
  bracket_pickem: 'Bracket + pick\'em',
}

// marquee_tournament weeks only - the commissioner picks a real tournament
// + contest mode. conference/nationals weeks never take this config (they're
// always roster-scored, no commissioner choice - see PostseasonWeekRow below).
function MarqueeWeekRow({ leagueId, week, isCommissioner, tournaments }) {
  const qc = useQueryClient()
  const [mode, setMode] = useState(week.tournament_game_mode ?? '')
  const [tournamentId, setTournamentId] = useState(week.linked_tournament_id ?? '')

  const saveMutation = useMutation({
    mutationFn: () => api.configureWeek(leagueId, week.id, mode, Number(tournamentId)),
    onSuccess: () => {
      toast.success(`Week ${week.week_number} configured`)
      qc.invalidateQueries({ queryKey: ['league-weeks', leagueId] })
    },
    onError: (err) => toast.error('Could not save week config', { body: err.message }),
  })

  const configured = week.tournament_game_mode && week.linked_tournament_id
  const tournamentName = tournaments?.find((t) => String(t.id) === String(week.linked_tournament_id))?.name

  return (
    <div className="space-y-2 border-b border-mat-700 p-4 last:border-b-0">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="text-sm font-bold text-ink-100">
          Week {week.week_number}
          <span className="ml-2 text-xs font-normal text-ink-500">marquee tournament</span>
        </div>
        {configured ? <Badge color="gold">{MODE_LABEL[week.tournament_game_mode]}</Badge> : <Badge color="ink">Not configured</Badge>}
      </div>

      {isCommissioner && (
        <div className="grid gap-2 sm:grid-cols-[1fr_1fr_auto]">
          <Select value={tournamentId} onChange={(e) => setTournamentId(e.target.value)}>
            <option value="">Choose tournament…</option>
            {(tournaments ?? []).map((t) => (
              <option key={t.id} value={t.id}>
                {t.name} {t.year ? `(${t.year})` : ''}
              </option>
            ))}
          </Select>
          <Select value={mode} onChange={(e) => setMode(e.target.value)}>
            <option value="">Choose mode…</option>
            {Object.entries(MODE_LABEL).map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </Select>
          <Button size="sm" disabled={!mode || !tournamentId} loading={saveMutation.isPending} onClick={() => saveMutation.mutate()}>
            <Settings size={14} /> Save
          </Button>
        </div>
      )}

      {configured && tournamentName && <p className="text-xs text-ink-500">Linked to {tournamentName}</p>}
    </div>
  )
}

// conference/nationals weeks - always roster-scored like a normal week, just
// weighted more heavily in final standings. Nothing to configure.
function PostseasonWeekRow({ week }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-2 border-b border-mat-700 p-4 last:border-b-0">
      <div className="text-sm font-bold text-ink-100">
        Week {week.week_number}
        <span className="ml-2 text-xs font-normal text-ink-500">{week.week_type}</span>
      </div>
      <Badge color="gold">{week.weight_multiplier}x weight</Badge>
    </div>
  )
}

/** Commissioner (and member-visible) panel for the season's non-head-to-head
 * weeks - configure which real tournament + mode each marquee_tournament week
 * uses, and see the weighting on conference/nationals weeks (no config, those
 * are always roster-scored). */
export default function WeeksPanel({ leagueId, isCommissioner }) {
  const { data: weeks, isLoading } = useQuery({
    queryKey: ['league-weeks', leagueId],
    queryFn: () => api.leagueWeeks(leagueId),
  })

  const { data: tournamentsData } = useQuery({
    queryKey: ['tournaments', 'for-league-weeks'],
    queryFn: () => api.tournaments({ per: 100 }),
    enabled: isCommissioner,
  })
  const tournaments = tournamentsData?.items ?? tournamentsData?.tournaments ?? (Array.isArray(tournamentsData) ? tournamentsData : [])

  const marqueeWeeks = (weeks ?? []).filter((w) => w.week_type === 'marquee_tournament')
  const postseasonWeeks = (weeks ?? []).filter((w) => w.week_type === 'conference' || w.week_type === 'nationals')

  if (isLoading || (marqueeWeeks.length === 0 && postseasonWeeks.length === 0)) return null

  return (
    <div className="space-y-4">
      {marqueeWeeks.length > 0 && (
        <Card className="divide-y divide-mat-700 p-0">
          <div className="p-4 pb-0 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Marquee tournament weeks</div>
          {marqueeWeeks.map((week) => (
            <MarqueeWeekRow key={week.id} leagueId={leagueId} week={week} isCommissioner={isCommissioner} tournaments={tournaments} />
          ))}
        </Card>
      )}
      {postseasonWeeks.length > 0 && (
        <Card className="divide-y divide-mat-700 p-0">
          <div className="p-4 pb-0 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Postseason weeks</div>
          {postseasonWeeks.map((week) => (
            <PostseasonWeekRow key={week.id} week={week} />
          ))}
        </Card>
      )}
    </div>
  )
}

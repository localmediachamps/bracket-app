import React, { useState } from 'react'
import { Link } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Settings, Swords } from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Badge, Button, Card, Select } from '../ui'

const MODE_LABEL = {
  roster: 'Roster stays live',
  bracket: 'Bracket challenge (full field)',
  pickem: "Pick'em (full field)",
  bracket_pickem: 'Bracket + pick\'em',
  tournament_draft: 'Tournament mini-draft',
}

function WeekRow({ leagueId, week, isCommissioner, tournaments }) {
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
          <span className="ml-2 text-xs font-normal text-ink-500">{week.week_type.replace(/_/g, ' ')}</span>
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

      {week.tournament_game_mode === 'tournament_draft' && (
        <Link to={`/leagues/${leagueId}/draft/${week.id}`}>
          <Button variant="secondary" size="sm">
            <Swords size={14} /> Enter tournament draft
          </Button>
        </Link>
      )}
    </div>
  )
}

/** Commissioner (and member-visible) panel for the season's non-head-to-head
 * weeks - configure which real tournament + mode each one uses, and jump
 * into that week's mini-draft if it's using one. */
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

  const specialWeeks = (weeks ?? []).filter((w) => w.week_type !== 'head_to_head')

  if (isLoading || specialWeeks.length === 0) return null

  return (
    <Card className="divide-y divide-mat-700 p-0">
      <div className="p-4 pb-0 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Tournament weeks</div>
      {specialWeeks.map((week) => (
        <WeekRow key={week.id} leagueId={leagueId} week={week} isCommissioner={isCommissioner} tournaments={tournaments} />
      ))}
    </Card>
  )
}

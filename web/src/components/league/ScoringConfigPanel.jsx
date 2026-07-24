import React, { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Save } from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { cn } from '../../lib/utils'
import { Button, Input } from '../ui'

const VICTORY_TYPES = [
  { key: 'decision', label: 'Decision' },
  { key: 'major', label: 'Major decision' },
  { key: 'tech_fall', label: 'Tech fall' },
  { key: 'fall', label: 'Fall (pin)' },
  { key: 'medical_forfeit', label: 'Medical forfeit' },
  { key: 'injury_default', label: 'Injury default' },
  { key: 'forfeit', label: 'Forfeit' },
  { key: 'disqualification', label: 'Disqualification' },
]

const PLACEMENT_RANKS = [1, 2, 3, 4, 5, 6, 7, 8]

const MULTIPLIER_TIERS = [
  { key: 'contender', label: 'Contender', hint: 'ranked #1-4' },
  { key: 'all_american', label: 'All-American', hint: 'ranked #5-8' },
  { key: 'blood_round', label: 'Blood Round', hint: 'ranked #9-12' },
]

// This whole card exists because league.scoring_config was already fully
// wired into the scoring cron (tasks/score_league_weeks.xs overlays it on
// the site defaults every week) but had never had ANY settings UI - a
// commissioner literally could not change these values through the app.
export default function ScoringConfigPanel({ leagueId, scoringConfig, defaults, isCommissioner, draftHasStarted }) {
  const qc = useQueryClient()

  const [victoryPoints, setVictoryPoints] = useState({})
  const [medalBonus, setMedalBonus] = useState({})
  const [multipliers, setMultipliers] = useState({})
  const [h2hPoints, setH2hPoints] = useState({ win: '', tie: '', loss: '' })
  const [scoringMode, setScoringMode] = useState('full_sum')

  useEffect(() => {
    if (!defaults) return
    const vp = { ...defaults.victory_points, ...(scoringConfig?.victory_points ?? {}) }
    const mb = { ...defaults.medal_bonus, ...(scoringConfig?.medal_bonus ?? {}) }
    const mult = { ...defaults.opponent_multipliers, ...(scoringConfig?.opponent_multipliers ?? {}) }
    const h2h = { ...defaults.head_to_head_result_points, ...(scoringConfig?.head_to_head_result_points ?? {}) }

    setVictoryPoints(Object.fromEntries(Object.entries(vp).map(([k, v]) => [k, String(v)])))
    setMedalBonus(Object.fromEntries(Object.entries(mb).map(([k, v]) => [k, String(v)])))
    setMultipliers(
      Object.fromEntries(
        MULTIPLIER_TIERS.map((t) => [t.key, { ...mult[t.key], multiplier: String(mult[t.key]?.multiplier ?? 1) }])
      )
    )
    setH2hPoints({ win: String(h2h.win ?? 2), tie: String(h2h.tie ?? 1), loss: String(h2h.loss ?? 0) })
    setScoringMode(scoringConfig?.multi_match_scoring_mode ?? defaults.multi_match_scoring_mode ?? 'full_sum')
  }, [defaults, scoringConfig])

  const saveMutation = useMutation({
    mutationFn: () => {
      const toNumMap = (obj) => Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, v === '' ? 0 : Number(v)]))
      const opponent_multipliers = Object.fromEntries(
        MULTIPLIER_TIERS.map((t) => [
          t.key,
          { ...multipliers[t.key], multiplier: multipliers[t.key]?.multiplier === '' ? 1 : Number(multipliers[t.key]?.multiplier) },
        ])
      )
      return api.updateLeague(leagueId, {
        scoring_config: {
          victory_points: { ...toNumMap(victoryPoints), default: 0 },
          medal_bonus: { ...toNumMap(medalBonus), default: 0 },
          opponent_multipliers,
          head_to_head_result_points: toNumMap(h2hPoints),
          multi_match_scoring_mode: scoringMode,
        },
      })
    },
    onSuccess: () => {
      toast.success('Scoring configuration saved')
      qc.invalidateQueries({ queryKey: ['league', leagueId] })
    },
    onError: (err) => toast.error('Could not save', { body: err.message }),
  })

  if (!defaults) return null

  return (
    <div className="space-y-5">
      <div>
        <p className="mb-2 text-xs font-bold uppercase tracking-wide text-ink-500">
          Points per match, by how it ended
        </p>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
          {VICTORY_TYPES.map((vt) => (
            <Input
              key={vt.key}
              label={vt.label}
              type="number"
              step="0.5"
              value={victoryPoints[vt.key] ?? ''}
              onChange={(e) => setVictoryPoints((v) => ({ ...v, [vt.key]: e.target.value }))}
              disabled={!isCommissioner}
            />
          ))}
        </div>
      </div>

      <div>
        <p className="mb-2 text-xs font-bold uppercase tracking-wide text-ink-500">
          Medal bonus — extra points for a wrestler who placed at a tournament that week
        </p>
        <div className="grid grid-cols-4 gap-2 sm:grid-cols-8">
          {PLACEMENT_RANKS.map((r) => (
            <Input
              key={r}
              label={`#${r}`}
              type="number"
              step="0.5"
              value={medalBonus[String(r)] ?? ''}
              onChange={(e) => setMedalBonus((v) => ({ ...v, [String(r)]: e.target.value }))}
              disabled={!isCommissioner}
              className="text-center"
            />
          ))}
        </div>
      </div>

      <div>
        <p className="mb-2 text-xs font-bold uppercase tracking-wide text-ink-500">
          Opponent-quality multiplier — bonus for beating a highly-ranked wrestler
        </p>
        <div className="grid gap-2 sm:grid-cols-3">
          {MULTIPLIER_TIERS.map((t) => (
            <Input
              key={t.key}
              label={`${t.label} (${t.hint})`}
              type="number"
              step="0.05"
              value={multipliers[t.key]?.multiplier ?? ''}
              onChange={(e) => setMultipliers((v) => ({ ...v, [t.key]: { ...v[t.key], multiplier: e.target.value } }))}
              disabled={!isCommissioner}
            />
          ))}
        </div>
      </div>

      <div>
        <p className="mb-2 text-xs font-bold uppercase tracking-wide text-ink-500">
          Head-to-head result — flat points on top of the match total, for winning/tying/losing your weekly matchup
        </p>
        <div className="grid grid-cols-3 gap-2 sm:max-w-sm">
          <Input label="Win" type="number" step="0.5" value={h2hPoints.win} onChange={(e) => setH2hPoints((v) => ({ ...v, win: e.target.value }))} disabled={!isCommissioner} />
          <Input label="Tie" type="number" step="0.5" value={h2hPoints.tie} onChange={(e) => setH2hPoints((v) => ({ ...v, tie: e.target.value }))} disabled={!isCommissioner} />
          <Input label="Loss" type="number" step="0.5" value={h2hPoints.loss} onChange={(e) => setH2hPoints((v) => ({ ...v, loss: e.target.value }))} disabled={!isCommissioner} />
        </div>
      </div>

      <div>
        <p className="mb-1 text-xs font-bold uppercase tracking-wide text-ink-500">
          Multiple matches in a week — regular-season weeks only
        </p>
        <p className="mb-2 text-xs text-ink-500">
          Some regular-season weeks mix duals with tournaments, where a wrestler can pick up several real matches
          instead of just one. Choose how those matches combine into that lineup slot's score. Conference and
          nationals weeks always count every match at full value, regardless of this setting — the whole league is
          exclusively in tournament play those weeks, so there's no dual-vs-tournament mismatch to correct for.
        </p>
        <div className="grid gap-2 sm:grid-cols-2">
          <button
            type="button"
            disabled={!isCommissioner}
            onClick={() => setScoringMode('full_sum')}
            className={cn(
              'rounded-lg border p-3 text-left transition-colors disabled:cursor-not-allowed disabled:opacity-60',
              scoringMode === 'full_sum' ? 'border-gold-500/60 bg-gold-500/10' : 'border-mat-700 hover:border-mat-600'
            )}
          >
            <p className="text-sm font-bold text-ink-100">Full sum (default)</p>
            <p className="mt-0.5 text-xs text-ink-500">Every real match that week scores at full value.</p>
          </button>
          <button
            type="button"
            disabled={!isCommissioner}
            onClick={() => setScoringMode('average')}
            className={cn(
              'rounded-lg border p-3 text-left transition-colors disabled:cursor-not-allowed disabled:opacity-60',
              scoringMode === 'average' ? 'border-gold-500/60 bg-gold-500/10' : 'border-mat-700 hover:border-mat-600'
            )}
          >
            <p className="text-sm font-bold text-ink-100">Average</p>
            <p className="mt-0.5 text-xs text-ink-500">Matches that week are normalized down to one match's worth.</p>
          </button>
        </div>
      </div>

      {isCommissioner && (
        <Button onClick={() => saveMutation.mutate()} loading={saveMutation.isPending}>
          <Save size={15} /> Save scoring configuration
        </Button>
      )}
    </div>
  )
}

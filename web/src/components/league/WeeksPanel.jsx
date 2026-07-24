import React, { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Search, Settings, Trophy, Plus, ChevronDown, Undo2 } from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { cn } from '../../lib/utils'
import { Badge, Button, Card, Input, Modal, Select } from '../ui'

const PLACEMENT_RANKS = [1, 2, 3, 4, 5, 6, 7, 8]

const MODE_LABEL = {
  bracket: 'Bracket challenge (full field)',
  pickem: "Pick'em (full field)",
  bracket_pickem: 'Bracket + pick\'em',
}

function fmtDate(ms) {
  if (!ms) return ''
  return new Date(ms).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

function round2(n) {
  return Math.round(n * 100) / 100
}

function scaledTable(baseTable, multiplier) {
  const out = {}
  for (const rank of PLACEMENT_RANKS) {
    out[String(rank)] = round2((baseTable?.[String(rank)] ?? 0) * multiplier)
  }
  out.default = 0
  return out
}

// Detects what multiplier (if any) an already-saved placement_points_config
// represents relative to the shared base table, so re-opening a week that
// was already scaled shows the real slider position instead of resetting
// to the type default every time.
function detectMultiplier(existingConfig, baseTable, fallback) {
  if (!existingConfig || !baseTable) return fallback
  const base1 = baseTable['1']
  const existing1 = existingConfig['1']
  if (!base1 || existing1 == null) return fallback
  return round2(existing1 / base1)
}

// Shared by marquee tournament weeks and postseason (conference/nationals)
// weeks - a single multiplier scales every placement value up/down together,
// preserving the ratios between places, instead of the commissioner typing
// eight (or nine) numbers by hand. Saving still writes the exact same
// rank->points table shape the backend already expects - only the input
// method changed.
function PlacementScaleControl({ baseTable, defaultMultiplier, existingConfig, onSave, saving }) {
  const [multiplier, setMultiplier] = useState(() => detectMultiplier(existingConfig, baseTable, defaultMultiplier))
  const preview = useMemo(() => scaledTable(baseTable, multiplier), [baseTable, multiplier])
  const isDefault = round2(multiplier) === round2(defaultMultiplier)

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-3">
        <label className="text-xs font-bold uppercase tracking-wide text-ink-500">Point scale</label>
        <input
          type="range"
          min={0.25}
          max={4}
          step={0.25}
          value={multiplier}
          onChange={(e) => setMultiplier(Number(e.target.value))}
          className="h-1.5 w-40 accent-gold-500"
        />
        <div className="flex items-center gap-1.5">
          <input
            type="number"
            min={0.25}
            max={10}
            step={0.25}
            value={multiplier}
            onChange={(e) => setMultiplier(Number(e.target.value) || 0)}
            className="w-16 rounded-lg border border-mat-700 bg-mat-850 px-2 py-1 text-center text-sm text-ink-100 focus:border-gold-500/50 focus:outline-none"
          />
          <span className="text-sm font-bold text-ink-400">×</span>
        </div>
        <Badge color={isDefault ? 'ink' : 'gold'}>{isDefault ? 'Default scale' : 'Custom scale'}</Badge>
      </div>

      <div className="grid grid-cols-4 gap-1.5 sm:grid-cols-8">
        {PLACEMENT_RANKS.map((r) => (
          <div key={r} className="rounded-lg border border-mat-700 bg-mat-850/50 px-2 py-1.5 text-center">
            <div className="text-[10px] font-bold text-ink-600">#{r}</div>
            <div className="font-mono text-sm font-bold text-gold-400">{preview[String(r)]}</div>
          </div>
        ))}
      </div>

      <Button size="sm" loading={saving} onClick={() => onSave(preview)}>
        <Settings size={14} /> Save point scale
      </Button>
    </div>
  )
}

function TournamentPickerModal({ open, onClose, tournaments, search, onSearch, onPick }) {
  const filtered = (tournaments ?? []).filter((t) => !search || t.name.toLowerCase().includes(search.toLowerCase()))

  return (
    <Modal open={open} onClose={onClose} title="Choose a tournament" wide>
      <div className="relative mb-3">
        <Search size={14} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-500" />
        <Input value={search} onChange={(e) => onSearch(e.target.value)} placeholder="Search tournaments…" className="pl-8" />
      </div>
      <div className="max-h-96 space-y-1.5 overflow-y-auto">
        {filtered.map((t) => (
          <button
            key={t.id}
            onClick={() => onPick(t)}
            className="flex w-full items-center justify-between rounded-lg border border-mat-700 px-3.5 py-2.5 text-left hover:border-gold-500/50 hover:bg-mat-800/50"
          >
            <div className="min-w-0">
              <p className="truncate text-sm font-semibold text-ink-100">{t.name}</p>
              <p className="text-xs text-ink-500">
                {t.year} {t.location ? `· ${t.location}` : ''}
              </p>
            </div>
            <span className="shrink-0 text-xs font-bold text-gold-400">Select →</span>
          </button>
        ))}
        {filtered.length === 0 && <p className="p-6 text-center text-sm text-ink-500">No tournaments match that search.</p>}
      </div>
    </Modal>
  )
}

// Weeks this league could flag as marquee (still head_to_head for this
// league, not yet locked/scored) - or, once at least one marquee week
// exists, weeks this league could revert back to head_to_head.
function WeekTypePickerModal({ open, onClose, eligibleWeeks, onPick, saving }) {
  return (
    <Modal open={open} onClose={onClose} title="Make a week marquee">
      <p className="mb-3 text-xs text-ink-500">
        Only for your league - other leagues sharing this season keep their own choice for these weeks.
      </p>
      <div className="max-h-96 space-y-1.5 overflow-y-auto">
        {eligibleWeeks.map((w) => (
          <button
            key={w.id}
            disabled={saving}
            onClick={() => onPick(w)}
            className="flex w-full items-center justify-between rounded-lg border border-mat-700 px-3.5 py-2.5 text-left hover:border-gold-500/50 hover:bg-mat-800/50 disabled:opacity-50"
          >
            <div>
              <p className="text-sm font-semibold text-ink-100">Week {w.week_number}</p>
              <p className="text-xs text-ink-500">
                {fmtDate(w.starts_at)}–{fmtDate(w.ends_at)}
              </p>
            </div>
            <span className="shrink-0 text-xs font-bold text-gold-400">Make marquee →</span>
          </button>
        ))}
        {eligibleWeeks.length === 0 && (
          <p className="p-6 text-center text-sm text-ink-500">
            No upcoming head-to-head weeks left to convert - once a week opens, locks, or scores it can't change type.
          </p>
        )}
      </div>
    </Modal>
  )
}

// One row of the marquee-weeks table - collapsed shows the week's current
// state at a glance, expanded reveals the tournament picker + point scale.
function MarqueeWeekTableRow({ leagueId, week, isCommissioner, tournaments, baseTable, expanded, onToggle }) {
  const qc = useQueryClient()
  const [pickerOpen, setPickerOpen] = useState(false)
  const [search, setSearch] = useState('')
  const [mode, setMode] = useState(week.tournament_game_mode ?? 'bracket_pickem')

  const configured = week.tournament_game_mode && week.linked_tournament_id
  const tournamentName = tournaments?.find((t) => String(t.id) === String(week.linked_tournament_id))?.name
  const scaleMultiplier = detectMultiplier(week.placement_points_config, baseTable, 1)

  const saveConfigMutation = useMutation({
    mutationFn: (tournament) => api.configureWeek(leagueId, week.id, mode, tournament.id, week.placement_points_config ?? undefined),
    onSuccess: () => {
      toast.success(`Week ${week.week_number} linked to a tournament`)
      qc.invalidateQueries({ queryKey: ['league-weeks', leagueId] })
      setPickerOpen(false)
    },
    onError: (err) => toast.error('Could not save week config', { body: err.message }),
  })

  const saveScaleMutation = useMutation({
    mutationFn: (placementPointsConfig) => api.configureWeek(leagueId, week.id, week.tournament_game_mode, week.linked_tournament_id, placementPointsConfig),
    onSuccess: () => {
      toast.success(`Week ${week.week_number} point scale saved`)
      qc.invalidateQueries({ queryKey: ['league-weeks', leagueId] })
    },
    onError: (err) => toast.error('Could not save', { body: err.message }),
  })

  const revertMutation = useMutation({
    mutationFn: () => api.setWeekType(leagueId, week.id, 'head_to_head'),
    onSuccess: () => {
      toast.success(`Week ${week.week_number} is head-to-head again`)
      qc.invalidateQueries({ queryKey: ['league-weeks', leagueId] })
    },
    onError: (err) => toast.error('Could not revert', { body: err.message }),
  })

  return (
    <>
      <tr className={cn('cursor-pointer transition-colors hover:bg-mat-800/40', expanded && 'bg-mat-800/40')} onClick={onToggle}>
        <td className="rounded-l-lg px-2 py-2 font-mono text-sm text-ink-300">Wk {week.week_number}</td>
        <td className="px-2 py-2 text-xs text-ink-500">
          {fmtDate(week.starts_at)}–{fmtDate(week.ends_at)}
        </td>
        <td className="px-2 py-2 text-sm font-semibold text-ink-100">{configured ? tournamentName ?? '—' : 'Not yet chosen'}</td>
        <td className="px-2 py-2">
          {configured ? <Badge color="gold">{MODE_LABEL[week.tournament_game_mode]}</Badge> : <Badge color="ink">Not configured</Badge>}
        </td>
        <td className="px-2 py-2">
          <Badge color={round2(scaleMultiplier) === 1 ? 'ink' : 'gold'}>{round2(scaleMultiplier) === 1 ? 'Default' : `${scaleMultiplier}×`}</Badge>
        </td>
        <td className="rounded-r-lg px-2 py-2 text-right">
          <ChevronDown size={16} className={cn('inline-block text-ink-500 transition-transform', expanded && 'rotate-180')} />
        </td>
      </tr>
      {expanded && (
        <tr>
          <td colSpan={6} className="px-2 pb-4">
            <div className="space-y-3 rounded-lg border border-mat-700 bg-mat-850/50 p-3">
              {isCommissioner && (
                <div className="flex flex-wrap items-center gap-2">
                  <Select value={mode} onChange={(e) => setMode(e.target.value)} className="w-auto" onClick={(e) => e.stopPropagation()}>
                    {Object.entries(MODE_LABEL).map(([key, label]) => (
                      <option key={key} value={key}>
                        {label}
                      </option>
                    ))}
                  </Select>
                  <Button variant="secondary" size="sm" onClick={(e) => { e.stopPropagation(); setPickerOpen(true) }}>
                    <Trophy size={14} /> {configured ? 'Change tournament' : 'Choose tournament'}
                  </Button>
                  {week.status === 'upcoming' && (
                    <Button
                      variant="ghost"
                      size="sm"
                      loading={revertMutation.isPending}
                      onClick={(e) => { e.stopPropagation(); revertMutation.mutate() }}
                    >
                      <Undo2 size={14} /> Revert to head-to-head
                    </Button>
                  )}
                </div>
              )}

              {configured && isCommissioner && (
                <div onClick={(e) => e.stopPropagation()}>
                  <PlacementScaleControl
                    baseTable={baseTable}
                    defaultMultiplier={1}
                    existingConfig={week.placement_points_config}
                    saving={saveScaleMutation.isPending}
                    onSave={(table) => saveScaleMutation.mutate(table)}
                  />
                </div>
              )}
            </div>
          </td>
        </tr>
      )}

      <TournamentPickerModal
        open={pickerOpen}
        onClose={() => setPickerOpen(false)}
        tournaments={tournaments}
        search={search}
        onSearch={setSearch}
        onPick={(t) => saveConfigMutation.mutate(t)}
      />
    </>
  )
}

const POSTSEASON_LABEL = {
  conference: { title: 'Conference Championships', hint: 'Every member scores their own roster and is ranked against the whole league.' },
  nationals: { title: 'National Championships', hint: 'The biggest week of the season - everyone\'s roster counts, ranked league-wide.' },
}

// conference/nationals weeks - always roster-scored (no tournament/mode to
// pick), just a placement-points scale relative to the same marquee base
// table. Defaults to 1.5x for conference, 2x for nationals. Universal across
// every league in the season - never per-league overridable.
function PostseasonWeekRow({ leagueId, week, isCommissioner, baseTable }) {
  const qc = useQueryClient()
  const label = POSTSEASON_LABEL[week.week_type] ?? { title: week.week_type, hint: '' }
  const defaultMultiplier = week.week_type === 'nationals' ? 2 : 1.5

  const saveMutation = useMutation({
    mutationFn: (placementPointsConfig) => api.configureWeekPlacementPoints(leagueId, week.id, placementPointsConfig),
    onSuccess: () => {
      toast.success(`${label.title} point scale saved`)
      qc.invalidateQueries({ queryKey: ['league-weeks', leagueId] })
    },
    onError: (err) => toast.error('Could not save', { body: err.message }),
  })

  return (
    <div className="space-y-3 border-b border-mat-700 p-4 last:border-b-0">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <div className="font-display text-lg uppercase tracking-tight text-ink-100">{label.title}</div>
          <p className="text-xs text-ink-500">{label.hint}</p>
        </div>
        <Badge color="ink">Week {week.week_number}</Badge>
      </div>

      {isCommissioner ? (
        <PlacementScaleControl
          baseTable={baseTable}
          defaultMultiplier={defaultMultiplier}
          existingConfig={week.placement_points_config}
          saving={saveMutation.isPending}
          onSave={(table) => saveMutation.mutate(table)}
        />
      ) : (
        week.placement_points_config && (
          <p className="text-xs text-ink-500">
            {PLACEMENT_RANKS.filter((r) => week.placement_points_config[String(r)] != null)
              .map((r) => `#${r}: ${week.placement_points_config[String(r)]}`)
              .join(' · ')}
          </p>
        )
      )}
    </div>
  )
}

/** Commissioner (and member-visible) panel for the season's non-head-to-head
 * weeks. Marquee weeks are per-league - a commissioner can flag any upcoming
 * head-to-head week as marquee for their own league (independent of every
 * other league sharing the season), then browse every tournament available
 * this season and pick one + a contest mode, scaling its placement points
 * off a shared base table via a single multiplier. Postseason (conference/
 * nationals) stays universal across every league, unchanged. */
export default function WeeksPanel({ leagueId, isCommissioner }) {
  const qc = useQueryClient()
  const [expandedWeekId, setExpandedWeekId] = useState(null)
  const [addPickerOpen, setAddPickerOpen] = useState(false)

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

  const { data: defaults } = useQuery({
    queryKey: ['league-scoring-defaults'],
    queryFn: () => api.leagueScoringDefaults(),
  })
  const baseTable = defaults?.placement_points_defaults?.marquee_tournament

  const marqueeWeeks = (weeks ?? []).filter((w) => w.week_type === 'marquee_tournament')
  const postseasonWeeks = (weeks ?? []).filter((w) => w.week_type === 'conference' || w.week_type === 'nationals')
  const eligibleWeeks = (weeks ?? []).filter((w) => w.week_type === 'head_to_head' && w.status === 'upcoming')

  const setTypeMutation = useMutation({
    mutationFn: (week) => api.setWeekType(leagueId, week.id, 'marquee_tournament'),
    onSuccess: (_, week) => {
      toast.success(`Week ${week.week_number} is now a marquee week for your league`)
      qc.invalidateQueries({ queryKey: ['league-weeks', leagueId] })
      setAddPickerOpen(false)
      setExpandedWeekId(week.id)
    },
    onError: (err) => toast.error('Could not change week type', { body: err.message }),
  })

  if (isLoading || !baseTable) return null
  if (marqueeWeeks.length === 0 && postseasonWeeks.length === 0 && eligibleWeeks.length === 0) return null

  return (
    <div className="space-y-4">
      {(marqueeWeeks.length > 0 || (isCommissioner && eligibleWeeks.length > 0)) && (
        <Card className="p-4">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            <div>
              <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Marquee tournament weeks</div>
              <p className="mt-0.5 text-xs text-ink-500">
                Regular-season events your league competes in instead of head-to-head that week - your choice, independent of other leagues.
              </p>
            </div>
            {isCommissioner && (
              <Button variant="secondary" size="sm" onClick={() => setAddPickerOpen(true)}>
                <Plus size={14} /> Add a marquee week
              </Button>
            )}
          </div>

          {marqueeWeeks.length > 0 ? (
            <div className="overflow-x-auto -mx-1 px-1">
              <table className="w-full min-w-[640px] border-separate border-spacing-y-1.5">
                <thead>
                  <tr className="text-left text-[10px] font-bold uppercase tracking-[0.12em] text-ink-500">
                    <th className="w-16 px-2">Week</th>
                    <th className="w-28 px-2">Dates</th>
                    <th className="px-2">Tournament</th>
                    <th className="px-2">Mode</th>
                    <th className="w-24 px-2">Scale</th>
                    <th className="w-8 px-2" aria-label="expand" />
                  </tr>
                </thead>
                <tbody>
                  {marqueeWeeks.map((week) => (
                    <MarqueeWeekTableRow
                      key={week.id}
                      leagueId={leagueId}
                      week={week}
                      isCommissioner={isCommissioner}
                      tournaments={tournaments}
                      baseTable={baseTable}
                      expanded={expandedWeekId === week.id}
                      onToggle={() => setExpandedWeekId((cur) => (cur === week.id ? null : week.id))}
                    />
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="text-sm text-ink-500">No marquee weeks yet - add one to run a bracket/pick'em week instead of head-to-head.</p>
          )}
        </Card>
      )}

      {postseasonWeeks.length > 0 && (
        <Card className="divide-y divide-mat-700 p-0">
          <div className="p-4 pb-0">
            <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Postseason</div>
            <p className="mt-0.5 text-xs text-ink-500">Conference and national championships - the two weeks that matter most, the same for every league this season.</p>
          </div>
          {postseasonWeeks.map((week) => (
            <PostseasonWeekRow key={week.id} leagueId={leagueId} week={week} isCommissioner={isCommissioner} baseTable={baseTable} />
          ))}
        </Card>
      )}

      <WeekTypePickerModal
        open={addPickerOpen}
        onClose={() => setAddPickerOpen(false)}
        eligibleWeeks={eligibleWeeks}
        saving={setTypeMutation.isPending}
        onPick={(w) => setTypeMutation.mutate(w)}
      />
    </div>
  )
}

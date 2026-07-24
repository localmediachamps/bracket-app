import React, { useEffect, useState } from 'react'
import { Link, Navigate, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { ArrowLeft, Info, Save, Shield, Trophy } from 'lucide-react'
import { api } from '../lib/api'
import { toast } from '../lib/store'
import { Badge, Button, Card, Input, Select, Skeleton, Textarea } from '../components/ui'
import InviteMemberBox from '../components/league/InviteMemberBox'
import WeeksPanel from '../components/league/WeeksPanel'
import ScoringConfigPanel from '../components/league/ScoringConfigPanel'
import { cn } from '../lib/utils'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

// A settings section always pairs the control with a plain-language "what
// this actually does" line - the postseason placement-points card in
// particular used to show up with zero explanation anywhere in the app.
function SettingCard({ title, description, children }) {
  return (
    <Card className="p-5">
      <h2 className="text-sm font-bold uppercase tracking-wide text-ink-100">{title}</h2>
      {description && (
        <p className="mt-1 flex items-start gap-1.5 text-xs leading-relaxed text-ink-500">
          <Info size={13} className="mt-0.5 shrink-0 text-ink-600" />
          <span>{description}</span>
        </p>
      )}
      <div className="mt-4">{children}</div>
    </Card>
  )
}

export default function LeagueSettings() {
  const { id } = useParams()
  const qc = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['league', id],
    queryFn: () => api.league(id),
  })

  const { data: scoringDefaults } = useQuery({
    queryKey: ['league-scoring-defaults'],
    queryFn: () => api.leagueScoringDefaults(),
  })

  const league = data?.league
  const myMembership = data?.my_membership
  const isCommissioner = myMembership?.role === 'owner' || myMembership?.role === 'commissioner'
  const draftHasStarted = league && league.status !== 'forming'

  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [privacy, setPrivacy] = useState('private')
  const [memberLimit, setMemberLimit] = useState('')
  const [alternateMode, setAlternateMode] = useState('per_weight')
  const [alternateSlots, setAlternateSlots] = useState('')
  const [alternatePoolSize, setAlternatePoolSize] = useState('')

  useEffect(() => {
    if (!league) return
    setName(league.name ?? '')
    setDescription(league.description ?? '')
    setPrivacy(league.privacy ?? 'private')
    setMemberLimit(league.member_limit != null ? String(league.member_limit) : '')
    setAlternateMode(league.roster_alternate_mode ?? 'per_weight')
    setAlternateSlots(String(league.roster_alternate_slots ?? 1))
    setAlternatePoolSize(String(league.roster_alternate_pool_size ?? 5))
  }, [league])

  const saveInfoMutation = useMutation({
    mutationFn: () =>
      api.updateLeague(id, {
        name: name.trim(),
        description: description.trim(),
        privacy,
        member_limit: memberLimit ? Number(memberLimit) : undefined,
      }),
    onSuccess: () => {
      toast.success('League info saved')
      qc.invalidateQueries({ queryKey: ['league', id] })
    },
    onError: (err) => toast.error('Could not save', { body: err.message }),
  })

  const saveRosterMutation = useMutation({
    mutationFn: () =>
      api.updateLeague(id, {
        roster_alternate_mode: alternateMode,
        roster_alternate_slots: alternateMode === 'per_weight' ? Number(alternateSlots) : undefined,
        roster_alternate_pool_size: alternateMode === 'flat_pool' ? Number(alternatePoolSize) : undefined,
      }),
    onSuccess: () => {
      toast.success('Roster configuration saved')
      qc.invalidateQueries({ queryKey: ['league', id] })
    },
    onError: (err) => toast.error('Could not save', { body: err.message }),
  })

  if (isLoading) {
    return (
      <div className="space-y-6 py-6">
        <Skeleton className="h-9 w-64" />
        <Skeleton className="h-48 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    )
  }

  if (!isCommissioner) {
    return <Navigate to={`/leagues/${id}`} replace />
  }

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="space-y-6 py-6">
      <Link to={`/leagues/${id}`} className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to league
      </Link>

      <motion.header variants={rise} className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="flex items-center gap-2 font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">
            <Shield size={22} className="text-gold-400" /> Commissioner <span className="text-gold-400">Settings</span>
          </h1>
          <p className="mt-1 text-sm text-ink-500">Only visible to you — the owner and any commissioners of {league?.name}.</p>
        </div>
        <Badge color="gold">{myMembership?.role}</Badge>
      </motion.header>

      <motion.div variants={rise}>
        <SettingCard title="League info" description="Basic identity - what members see when they open this league.">
          <div className="space-y-3">
            <Input label="Name" value={name} onChange={(e) => setName(e.target.value)} />
            <Textarea label="Description" value={description} onChange={(e) => setDescription(e.target.value)} rows={3} />
            <div className="grid gap-3 sm:grid-cols-2">
              <Select
                label="Privacy"
                value={privacy}
                onChange={(e) => setPrivacy(e.target.value)}
              >
                <option value="private">Private — invite only, hidden from non-members</option>
                <option value="unlisted">Unlisted — anyone with the link can view, still invite-only to join</option>
              </Select>
              <Input label="Member limit" type="number" min={2} value={memberLimit} onChange={(e) => setMemberLimit(e.target.value)} />
            </div>
            <Button onClick={() => saveInfoMutation.mutate()} loading={saveInfoMutation.isPending}>
              <Save size={15} /> Save league info
            </Button>
          </div>
        </SettingCard>
      </motion.div>

      <motion.div variants={rise}>
        <SettingCard
          title="Roster configuration"
          description={
            draftHasStarted
              ? "Locked once the draft starts - changing roster shape after picks exist would leave rosters inconsistent with what was actually drafted."
              : "Every team gets one starter per weight class - that's fixed by how many weight classes college wrestling has, not something to configure. What you do control is the bench: either a fixed number of backups at every weight, or one shared pool of backups your teams can stack however they want."
          }
        >
          <div className="space-y-4">
            <div className="rounded-lg border border-mat-700 bg-mat-850/50 px-3.5 py-2.5">
              <p className="text-xs font-bold uppercase tracking-wide text-ink-500">Starters</p>
              <p className="mt-0.5 text-sm text-ink-200">10 — one per weight class (125 through 285 lbs), always.</p>
            </div>

            <div>
              <p className="mb-2 text-xs font-bold uppercase tracking-wide text-ink-500">Bench / alternates</p>
              <div className="grid gap-2 sm:grid-cols-2">
                <button
                  type="button"
                  disabled={draftHasStarted}
                  onClick={() => setAlternateMode('per_weight')}
                  className={cn(
                    'rounded-lg border p-3 text-left transition-colors disabled:cursor-not-allowed disabled:opacity-60',
                    alternateMode === 'per_weight' ? 'border-gold-500/60 bg-gold-500/10' : 'border-mat-700 hover:border-mat-600'
                  )}
                >
                  <p className="text-sm font-bold text-ink-100">One backup per weight</p>
                  <p className="mt-0.5 text-xs text-ink-500">A fixed number of bench slots at every single weight class.</p>
                </button>
                <button
                  type="button"
                  disabled={draftHasStarted}
                  onClick={() => setAlternateMode('flat_pool')}
                  className={cn(
                    'rounded-lg border p-3 text-left transition-colors disabled:cursor-not-allowed disabled:opacity-60',
                    alternateMode === 'flat_pool' ? 'border-gold-500/60 bg-gold-500/10' : 'border-mat-700 hover:border-mat-600'
                  )}
                >
                  <p className="text-sm font-bold text-ink-100">Custom total pool</p>
                  <p className="mt-0.5 text-xs text-ink-500">One shared number of bench spots - stack them on any weight(s) you want.</p>
                </button>
              </div>
            </div>

            {alternateMode === 'per_weight' ? (
              <Input
                label="Backups per weight class"
                type="number"
                min={0}
                value={alternateSlots}
                onChange={(e) => setAlternateSlots(e.target.value)}
                disabled={draftHasStarted}
              />
            ) : (
              <Input
                label="Total bench pool size"
                type="number"
                min={0}
                value={alternatePoolSize}
                onChange={(e) => setAlternatePoolSize(e.target.value)}
                disabled={draftHasStarted}
              />
            )}
          </div>
          {!draftHasStarted && (
            <Button className="mt-3" onClick={() => saveRosterMutation.mutate()} loading={saveRosterMutation.isPending}>
              <Save size={15} /> Save roster configuration
            </Button>
          )}
        </SettingCard>
      </motion.div>

      <motion.div variants={rise}>
        <SettingCard
          title="Scoring configuration"
          description="How fantasy points get calculated every week, across every week type. These apply on top of the per-week placement points below - a wrestler's own match results always feed the same season-long points ledger."
        >
          <ScoringConfigPanel
            leagueId={id}
            scoringConfig={league?.scoring_config}
            defaults={scoringDefaults}
            isCommissioner={isCommissioner}
            draftHasStarted={draftHasStarted}
          />
        </SettingCard>
      </motion.div>

      <motion.div variants={rise}>
        <SettingCard
          title="Season week scoring"
          description="Marquee tournament weeks: pick which real tournament + contest mode (bracket/pick'em) the whole league competes in that week instead of head-to-head. Postseason (conference/nationals) weeks: everyone's roster is scored and ranked against the whole league instead of paired 1v1 - customize how many season-standing points each final place is worth, or leave blank to use the site default."
        >
          <WeeksPanel leagueId={id} isCommissioner={isCommissioner} />
        </SettingCard>
      </motion.div>

      <motion.div variants={rise}>
        <SettingCard title="Invite members" description="Leagues are invite-only by account - look up an existing user by their exact username and send them an invite.">
          <InviteMemberBox leagueId={id} />
        </SettingCard>
      </motion.div>

      {!draftHasStarted && (
        <motion.div variants={rise}>
          <SettingCard title="Draft" description="Once you're ready and every roster-config decision above is final, start the draft from the league page or draft room - it can't be undone.">
            <Link to={`/leagues/${id}/draft`}>
              <Button variant="secondary">
                <Trophy size={15} /> Go to draft room
              </Button>
            </Link>
          </SettingCard>
        </motion.div>
      )}
    </motion.div>
  )
}

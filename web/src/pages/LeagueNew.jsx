import React, { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import confetti from 'canvas-confetti'
import { AlertTriangle, ArrowLeft, ArrowRight, Lock, Link2, PartyPopper, RefreshCw, Users } from 'lucide-react'
import { api } from '../lib/api'
import { toast } from '../lib/store'
import { Button, Card, Input, Select, Skeleton, Textarea } from '../components/ui'
import EmojiPicker from '../components/groups/EmojiPicker'
import { LeagueStatusBadge } from '../components/league/LeagueCard'

const PRIVACY_OPTIONS = [
  { key: 'private', icon: Lock, label: 'Private', blurb: 'Invite specific accounts only. Nothing is discoverable.' },
  { key: 'unlisted', icon: Link2, label: 'Unlisted', blurb: 'Still invite-only, just a lighter badge on the league.' },
]

function fireConfetti() {
  const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  if (reduced) return
  const defaults = { origin: { y: 0.7 }, zIndex: 200 }
  confetti({ ...defaults, particleCount: 90, spread: 75, colors: ['#e8ae2e', '#f5c44f', '#ffd87a', '#f4f1ea'] })
  setTimeout(() => confetti({ ...defaults, particleCount: 50, spread: 110, scalar: 0.8, colors: ['#e8ae2e', '#3ecf8e', '#f4f1ea'] }), 220)
}

export default function LeagueNew() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [form, setForm] = useState({
    season_id: '',
    name: '',
    description: '',
    privacy: 'private',
    member_limit: '',
    avatar_emoji: '🤼',
  })
  const [errors, setErrors] = useState({})
  const [created, setCreated] = useState(null)

  const { data: seasons, isLoading: sLoading, isError: sError, error: sErr, refetch, isRefetching } = useQuery({
    queryKey: ['seasons'],
    queryFn: api.leagueSeasons,
  })

  const selectedSeason = (seasons ?? []).find((s) => String(s.id) === String(form.season_id))

  const mutation = useMutation({
    mutationFn: (payload) => api.createLeague(payload),
    onSuccess: (res) => {
      const league = res?.league ?? res
      setCreated(league)
      qc.invalidateQueries({ queryKey: ['my-leagues'] })
      fireConfetti()
      window.scrollTo({ top: 0, behavior: 'smooth' })
    },
    onError: (err) => {
      toast.error('Could not create league', { body: err.message })
    },
  })

  const set = (k) => (e) => {
    setForm((f) => ({ ...f, [k]: e.target.value }))
    setErrors((er) => ({ ...er, [k]: null }))
  }

  const submit = (e) => {
    e?.preventDefault()
    const er = {}
    if (!form.season_id) er.season_id = 'Pick a season.'
    if (!form.name.trim()) er.name = 'Give your league a name.'
    if (form.member_limit !== '' && (Number(form.member_limit) < 2 || Number.isNaN(Number(form.member_limit)))) {
      er.member_limit = 'Limit must be at least 2 (or leave blank).'
    }
    setErrors(er)
    if (Object.keys(er).length) return
    mutation.mutate({
      season_id: Number(form.season_id),
      name: form.name.trim(),
      description: form.description.trim() || undefined,
      privacy: form.privacy,
      member_limit: form.member_limit === '' ? undefined : Number(form.member_limit),
      avatar_emoji: form.avatar_emoji,
    })
  }

  if (created) {
    const code = created.invite_code
    return (
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        className="mx-auto max-w-xl py-12 text-center"
      >
        <span className="mx-auto mb-5 flex h-16 w-16 items-center justify-center rounded-2xl bg-gold-500/15 text-gold-400 shadow-glow-sm">
          <PartyPopper size={30} />
        </span>
        <h1 className="font-display text-3xl uppercase tracking-tight text-ink-100">
          <span className="text-shimmer">{created.name}</span> is live
        </h1>
        <p className="mt-2 text-sm text-ink-500">
          Invite specific accounts from the league page — leagues are invite-only, no open join.
        </p>

        <Card className="mt-8 p-6">
          <div className="text-[10px] font-bold uppercase tracking-[0.2em] text-ink-500">Status</div>
          <div className="mt-2 flex justify-center">
            <LeagueStatusBadge status={created.status ?? 'forming'} />
          </div>
          {code && (
            <>
              <div className="mt-4 text-[10px] font-bold uppercase tracking-[0.2em] text-ink-500">Reference code</div>
              <p className="mt-1 break-all rounded-lg bg-mat-900 px-3 py-2 font-mono text-xs text-ink-500">{code}</p>
            </>
          )}
        </Card>

        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Button size="lg" onClick={() => navigate(`/leagues/${created.id}`)}>
            Go to league <ArrowRight size={16} />
          </Button>
          <Link to="/leagues">
            <Button variant="secondary" size="lg">
              All my leagues
            </Button>
          </Link>
        </div>
      </motion.div>
    )
  }

  return (
    <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} className="mx-auto max-w-5xl py-6">
      <Link to="/leagues" className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to leagues
      </Link>
      <h1 className="mt-3 font-display text-3xl uppercase tracking-tight text-ink-100 sm:text-4xl">
        Start a <span className="text-gold-400">League</span>
      </h1>
      <p className="mt-1.5 text-sm text-ink-500">Draft the full D1 field, run a weekly lineup, chase the belt.</p>

      <form onSubmit={submit} className="mt-8 grid items-start gap-6 lg:grid-cols-[1fr_360px]">
        <div className="space-y-5">
          {sLoading ? (
            <Skeleton className="h-16 w-full" />
          ) : sError ? (
            <Card className="flex items-center justify-between gap-3 border-blood-500/40 p-4">
              <span className="flex items-center gap-2 text-sm text-blood-400">
                <AlertTriangle size={16} /> {sErr?.message || 'Could not load seasons.'}
              </span>
              <Button variant="secondary" size="sm" onClick={() => refetch()} loading={isRefetching}>
                <RefreshCw size={14} /> Retry
              </Button>
            </Card>
          ) : (
            <Select
              label="Season"
              value={form.season_id}
              onChange={set('season_id')}
              error={errors.season_id}
              disabled={!(seasons ?? []).length}
            >
              <option value="">{(seasons ?? []).length ? 'Choose a season…' : 'No seasons set up yet'}</option>
              {(seasons ?? []).map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name} ({s.year})
                </option>
              ))}
            </Select>
          )}

          <Input
            label="League name"
            value={form.name}
            onChange={set('name')}
            placeholder="Iron Six Fantasy"
            maxLength={60}
            error={errors.name}
          />
          <Textarea
            label="Description"
            value={form.description}
            onChange={set('description')}
            placeholder="Snake draft, weekly lineups, bowl season at the end."
            rows={3}
            maxLength={280}
          />
          <div>
            <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">Privacy</span>
            <div role="radiogroup" aria-label="League privacy" className="grid gap-2 sm:grid-cols-2">
              {PRIVACY_OPTIONS.map((opt) => {
                const active = form.privacy === opt.key
                return (
                  <button
                    key={opt.key}
                    type="button"
                    role="radio"
                    aria-checked={active}
                    onClick={() => setForm((f) => ({ ...f, privacy: opt.key }))}
                    className={
                      'flex flex-col gap-1.5 rounded-xl border p-3.5 text-left transition-all ' +
                      (active
                        ? 'border-gold-500 bg-gold-500/10 shadow-glow-sm'
                        : 'border-mat-600 bg-mat-800 hover:border-mat-500 hover:bg-mat-750')
                    }
                  >
                    <span className={'flex items-center gap-2 text-sm font-bold ' + (active ? 'text-gold-400' : 'text-ink-100')}>
                      <opt.icon size={15} />
                      {opt.label}
                    </span>
                    <span className="text-xs leading-relaxed text-ink-500">{opt.blurb}</span>
                  </button>
                )
              })}
            </div>
          </div>
          <Input
            label="Member limit"
            type="number"
            min={2}
            max={100}
            value={form.member_limit}
            onChange={set('member_limit')}
            placeholder="No limit"
            hint="Leave blank for unlimited members."
            error={errors.member_limit}
          />
          <div>
            <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">Avatar emoji</span>
            <EmojiPicker value={form.avatar_emoji} onChange={(v) => setForm((f) => ({ ...f, avatar_emoji: v }))} />
          </div>
        </div>

        <div className="lg:sticky lg:top-24">
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">Live preview</span>
          <Card className="p-5" aria-live="polite">
            <div className="flex items-center gap-3">
              <span className="flex h-14 w-14 items-center justify-center rounded-xl border border-mat-600 bg-mat-800 text-3xl" aria-hidden>
                {form.avatar_emoji}
              </span>
              <div className="min-w-0">
                <div className="truncate text-base font-bold text-ink-100">{form.name.trim() || 'Your league name'}</div>
                <div className="mt-1 flex items-center gap-2">
                  <LeagueStatusBadge status="forming" />
                  <span className="inline-flex items-center gap-1 text-xs text-ink-500">
                    <Users size={12} /> 1{form.member_limit ? `/${form.member_limit}` : ''}
                  </span>
                </div>
              </div>
            </div>
            <p className="mt-3 line-clamp-3 min-h-5 text-sm text-ink-400">
              {form.description.trim() || <span className="italic text-ink-600">No description yet.</span>}
            </p>
            <div className="mt-4 border-t border-mat-700 pt-4">
              <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Season</div>
              <div className="mt-1 text-sm font-semibold text-gold-400">
                {selectedSeason ? `${selectedSeason.name} (${selectedSeason.year})` : '—'}
              </div>
            </div>
          </Card>
          <Button type="submit" size="lg" className="mt-4 w-full" loading={mutation.isPending} disabled={sLoading || sError}>
            Create league
          </Button>
        </div>
      </form>
    </motion.div>
  )
}

import React, { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import confetti from 'canvas-confetti'
import { AlertTriangle, ArrowLeft, ArrowRight, PartyPopper, RefreshCw, Users } from 'lucide-react'
import { api } from '../lib/api'
import { toast } from '../lib/store'
import { Button, Card, Input, Select, Skeleton, Textarea } from '../components/ui'
import EmojiPicker from '../components/groups/EmojiPicker'
import PrivacyCards from '../components/groups/PrivacyCards'
import InviteBox, { inviteLink } from '../components/groups/InviteBox'
import { PrivacyBadge } from '../components/groups/GroupCard'

function fireConfetti() {
  const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  if (reduced) return
  const defaults = { origin: { y: 0.7 }, zIndex: 200 }
  confetti({ ...defaults, particleCount: 90, spread: 75, colors: ['#e8ae2e', '#f5c44f', '#ffd87a', '#f4f1ea'] })
  setTimeout(() => confetti({ ...defaults, particleCount: 50, spread: 110, scalar: 0.8, colors: ['#e8ae2e', '#3ecf8e', '#f4f1ea'] }), 220)
}

export default function GroupNew() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [form, setForm] = useState({
    tournament_id: '',
    name: '',
    description: '',
    privacy: 'private',
    member_limit: '',
    avatar_emoji: '🤼',
  })
  const [errors, setErrors] = useState({})
  const [created, setCreated] = useState(null)

  const { data: tData, isLoading: tLoading, isError: tError, error: tErr, refetch, isRefetching } = useQuery({
    queryKey: ['tournaments', 'groupable'],
    queryFn: () => api.tournaments({ per: 50 }),
  })

  const tournaments = useMemo(() => {
    const list = tData?.items ?? tData?.tournaments ?? (Array.isArray(tData) ? tData : [])
    return list.filter((t) => ['open', 'live'].includes(t.status))
  }, [tData])

  const selectedTournament = tournaments.find((t) => String(t.id) === String(form.tournament_id))

  const mutation = useMutation({
    mutationFn: (payload) => api.createGroup(payload),
    onSuccess: (res) => {
      const group = res?.id ? res : res?.group ?? res
      setCreated(group)
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      fireConfetti()
      window.scrollTo({ top: 0, behavior: 'smooth' })
    },
    onError: (err) => {
      toast.error('Could not create group', { body: err.message })
    },
  })

  const set = (k) => (e) => {
    setForm((f) => ({ ...f, [k]: e.target.value }))
    setErrors((er) => ({ ...er, [k]: null }))
  }

  const submit = (e) => {
    e?.preventDefault()
    const er = {}
    if (!form.tournament_id) er.tournament_id = 'Pick a tournament.'
    if (!form.name.trim()) er.name = 'Give your group a name.'
    if (form.member_limit !== '' && (Number(form.member_limit) < 2 || Number.isNaN(Number(form.member_limit)))) {
      er.member_limit = 'Limit must be at least 2 (or leave blank).'
    }
    setErrors(er)
    if (Object.keys(er).length) return
    mutation.mutate({
      tournament_id: Number(form.tournament_id),
      name: form.name.trim(),
      description: form.description.trim() || undefined,
      privacy: form.privacy,
      member_limit: form.member_limit === '' ? undefined : Number(form.member_limit),
      avatar_emoji: form.avatar_emoji,
    })
  }

  /* ── Success screen ─────────────────────────────────── */
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
        <p className="mt-2 text-sm text-ink-500">Share the invite code — first one to the top of the leaderboard takes the belt.</p>

        <Card className="mt-8 p-6">
          <div className="text-[10px] font-bold uppercase tracking-[0.2em] text-ink-500">Invite code</div>
          <div className="mt-3 flex justify-center">
            <InviteBox groupId={created.id} code={code} big />
          </div>
          <p className="mt-4 break-all rounded-lg bg-mat-900 px-3 py-2 font-mono text-xs text-ink-500">
            {inviteLink(created.id, code)}
          </p>
        </Card>

        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Button size="lg" onClick={() => navigate(`/groups/${created.id}`)}>
            Go to group <ArrowRight size={16} />
          </Button>
          <Link to="/groups">
            <Button variant="secondary" size="lg">
              All my groups
            </Button>
          </Link>
        </div>
      </motion.div>
    )
  }

  /* ── Form ───────────────────────────────────────────── */
  return (
    <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} className="mx-auto max-w-5xl py-6">
      <Link to="/groups" className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to groups
      </Link>
      <h1 className="mt-3 font-display text-3xl uppercase tracking-tight text-ink-100 sm:text-4xl">
        Start a <span className="text-gold-400">Group</span>
      </h1>
      <p className="mt-1.5 text-sm text-ink-500">Your crew, your leaderboard, your rules.</p>

      <form onSubmit={submit} className="mt-8 grid items-start gap-6 lg:grid-cols-[1fr_360px]">
        {/* left: fields */}
        <div className="space-y-5">
          {tLoading ? (
            <Skeleton className="h-16 w-full" />
          ) : tError ? (
            <Card className="flex items-center justify-between gap-3 border-blood-500/40 p-4">
              <span className="flex items-center gap-2 text-sm text-blood-400">
                <AlertTriangle size={16} /> {tErr?.message || 'Could not load tournaments.'}
              </span>
              <Button variant="secondary" size="sm" onClick={() => refetch()} loading={isRefetching}>
                <RefreshCw size={14} /> Retry
              </Button>
            </Card>
          ) : (
            <Select
              label="Tournament"
              value={form.tournament_id}
              onChange={set('tournament_id')}
              error={errors.tournament_id}
              disabled={!tournaments.length}
            >
              <option value="">{tournaments.length ? 'Choose a tournament…' : 'No open or live tournaments right now'}</option>
              {tournaments.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name} {t.year ? `(${t.year})` : ''} — {t.status}
                </option>
              ))}
            </Select>
          )}

          <Input
            label="Group name"
            value={form.name}
            onChange={set('name')}
            placeholder="Hawkeye Homers"
            maxLength={60}
            error={errors.name}
          />
          <Textarea
            label="Description"
            value={form.description}
            onChange={set('description')}
            placeholder="Loser buys the post-tournament pizza."
            rows={3}
            maxLength={280}
          />
          <div>
            <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">Privacy</span>
            <PrivacyCards value={form.privacy} onChange={(v) => setForm((f) => ({ ...f, privacy: v }))} />
          </div>
          <Input
            label="Member limit"
            type="number"
            min={2}
            max={500}
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

        {/* right: live invite preview */}
        <div className="lg:sticky lg:top-24">
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">Live preview</span>
          <Card className="p-5" aria-live="polite">
            <div className="flex items-center gap-3">
              <span className="flex h-14 w-14 items-center justify-center rounded-xl border border-mat-600 bg-mat-800 text-3xl" aria-hidden>
                {form.avatar_emoji}
              </span>
              <div className="min-w-0">
                <div className="truncate text-base font-bold text-ink-100">{form.name.trim() || 'Your group name'}</div>
                <div className="mt-1 flex items-center gap-2">
                  <PrivacyBadge privacy={form.privacy} />
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
              <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Tournament</div>
              <div className="mt-1 text-sm font-semibold text-gold-400">
                {selectedTournament ? `${selectedTournament.name}${selectedTournament.year ? ` ${selectedTournament.year}` : ''}` : '—'}
              </div>
              <div className="mt-3 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Invite code</div>
              <div className="mt-1 select-none font-mono text-lg font-bold tracking-[0.3em] text-ink-600 blur-[3px]">XXXXXXXX</div>
              <div className="mt-1 text-xs text-ink-600">Generated when you create the group.</div>
            </div>
          </Card>
          <Button type="submit" size="lg" className="mt-4 w-full" loading={mutation.isPending} disabled={tLoading || tError}>
            Create group
          </Button>
        </div>
      </form>
    </motion.div>
  )
}

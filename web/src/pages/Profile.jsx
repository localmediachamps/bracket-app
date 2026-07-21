import React, { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, Award, BarChart3, Crown, Flame, Medal, RefreshCw, Save, TrendingUp, UserRound, Upload } from 'lucide-react'
import { api } from '../lib/api'
import { toast, useAuthStore } from '../lib/store'
import { Avatar, Badge, Button, Card, EmptyState, Input, Select, Skeleton, Stat, Switch, Tabs, Textarea } from '../components/ui'
import { cn, formatPoints, pct } from '../lib/utils'
import Donut from '../components/profile/Donut'
import { HBarList } from '../components/profile/HBar'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

/** normalize an accuracy figure that may arrive as 0..1 or 0..100 */
const normAcc = (v) => (v == null || isNaN(v) ? null : v > 1 ? v / 100 : Number(v))

export default function Profile() {
  const [tab, setTab] = useState('edit')
  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="py-6">
      <motion.header variants={rise} className="mb-6">
        <h1 className="font-display text-3xl uppercase tracking-tight text-ink-100 sm:text-4xl">
          Your <span className="text-gold-400">Profile</span>
        </h1>
        <p className="mt-1.5 text-sm text-ink-500">How the arena sees you — and how you're actually doing.</p>
      </motion.header>
      <motion.div variants={rise}>
        <Tabs
          tabs={[
            { key: 'edit', label: 'Edit profile', icon: <UserRound size={15} /> },
            { key: 'stats', label: 'Stats', icon: <BarChart3 size={15} /> },
          ]}
          active={tab}
          onChange={setTab}
          className="mb-6"
        />
        {tab === 'edit' ? <EditTab /> : <StatsTab />}
      </motion.div>
    </motion.div>
  )
}

/* ══ Edit tab ═══════════════════════════════════════════ */
function EditTab() {
  const qc = useQueryClient()
  const setUser = useAuthStore((s) => s.setUser)
  const { data: me, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['me'],
    queryFn: api.me,
  })

  // Return trip from Stripe Checkout (success_url points here) - show a
  // toast and refresh billing status once, then clean the URL.
  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    if (params.get('checkout') === 'success') {
      toast.success('Welcome to the annual plan!', { body: 'It may take a few seconds for your account to update.' })
      qc.invalidateQueries({ queryKey: ['billing', 'status'] })
      window.history.replaceState({}, '', window.location.pathname)
    }
  }, [qc])

  const [form, setForm] = useState(null)
  useEffect(() => {
    if (me && !form) {
      setForm({
        display_name: me.display_name ?? me.name ?? '',
        username: me.username ?? '',
        avatar_url: me.avatar_url ?? '',
        favorite_school: me.favorite_school ?? '',
        bio: me.bio ?? '',
        leaderboard_visible: me.leaderboard_visible ?? true,
        leaderboard_name_mode: me.leaderboard_name_mode ?? 'display_name',
      })
    }
  }, [me, form])

  const mutation = useMutation({
    mutationFn: (payload) => api.updateMe(payload),
    onSuccess: (updated) => {
      setUser({ ...me, ...updated })
      qc.setQueryData(['me'], { ...me, ...updated })
      toast.success('Profile saved')
    },
    onError: (err) => toast.error('Could not save profile', { body: err.message }),
  })

  const avatarMutation = useMutation({
    mutationFn: (file) => api.uploadAvatar(file),
    onSuccess: (updated) => {
      setUser({ ...me, ...updated })
      qc.setQueryData(['me'], { ...me, ...updated })
      setForm((f) => ({ ...f, avatar_url: updated.avatar_url ?? f.avatar_url }))
      toast.success('Photo updated')
    },
    onError: (err) => toast.error('Could not upload photo', { body: err.message }),
  })
  const handleAvatarFile = (e) => {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (file) avatarMutation.mutate(file)
  }

  if (isLoading || !form) {
    return (
      <div className="mx-auto max-w-2xl space-y-5">
        <Skeleton className="h-24 w-full" />
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-24 w-full" />
      </div>
    )
  }
  if (isError) {
    return (
      <EmptyState
        icon={<AlertTriangle size={26} />}
        title="Could not load your profile"
        body={error?.message}
        action={
          <Button onClick={() => refetch()} loading={isRefetching}>
            <RefreshCw size={15} /> Try again
          </Button>
        }
      />
    )
  }

  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }))
  const dirty =
    form.display_name !== (me.display_name ?? me.name ?? '') ||
    form.username !== (me.username ?? '') ||
    form.avatar_url !== (me.avatar_url ?? '') ||
    form.favorite_school !== (me.favorite_school ?? '') ||
    form.bio !== (me.bio ?? '') ||
    form.leaderboard_visible !== (me.leaderboard_visible ?? true) ||
    form.leaderboard_name_mode !== (me.leaderboard_name_mode ?? 'display_name')

  const submit = (e) => {
    e?.preventDefault()
    mutation.mutate({
      display_name: form.display_name.trim() || undefined,
      username: form.username.trim() || undefined,
      avatar_url: form.avatar_url.trim() || null,
      favorite_school: form.favorite_school.trim() || null,
      bio: form.bio.trim() || null,
      leaderboard_visible: form.leaderboard_visible,
      leaderboard_name_mode: form.leaderboard_name_mode,
    })
  }

  return (
    <motion.form variants={stagger} initial="hidden" animate="show" onSubmit={submit} className="mx-auto max-w-2xl space-y-5">
      <motion.div variants={rise}>
        <Card className="flex items-center gap-4 p-5">
          <div className="relative shrink-0">
            <Avatar user={{ ...me, ...form }} size="xl" ring />
            <label className="absolute -bottom-1 -right-1 flex h-7 w-7 cursor-pointer items-center justify-center rounded-full border border-mat-600 bg-mat-800 text-ink-300 shadow-card transition-colors hover:border-gold-500/50 hover:text-gold-400">
              <Upload size={13} />
              <input type="file" accept="image/*" className="sr-only" onChange={handleAvatarFile} disabled={avatarMutation.isPending} />
            </label>
          </div>
          <div className="min-w-0 flex-1">
            <div className="truncate text-base font-bold text-ink-100">{form.display_name || 'Your name'}</div>
            <div className="truncate text-sm text-ink-500">@{form.username || 'username'}</div>
            {form.favorite_school && (
              <Badge color="gold" className="mt-2 normal-case">
                {form.favorite_school}
              </Badge>
            )}
          </div>
          {avatarMutation.isPending && <span className="shrink-0 text-xs text-ink-500">Uploading…</span>}
        </Card>
      </motion.div>

      <motion.div variants={rise} className="grid gap-5 sm:grid-cols-2">
        <Input label="Display name" value={form.display_name} onChange={set('display_name')} maxLength={60} placeholder="Mat Wizard" />
        <Input label="Username" value={form.username} onChange={set('username')} maxLength={30} placeholder="matwizard" hint="Letters, numbers, underscores." />
      </motion.div>
      <motion.div variants={rise}>
        <Input
          label="Avatar URL"
          type="url"
          value={form.avatar_url}
          onChange={set('avatar_url')}
          placeholder="https://…"
          hint="Paste a link to a square image — the preview updates live."
        />
      </motion.div>
      <motion.div variants={rise}>
        <Input label="Favorite school" value={form.favorite_school} onChange={set('favorite_school')} maxLength={60} placeholder="Penn State" />
      </motion.div>
      <motion.div variants={rise}>
        <Textarea label="Bio" value={form.bio} onChange={set('bio')} rows={3} maxLength={280} placeholder="Been picking upsets since '97." />
      </motion.div>

      <motion.div variants={rise} className="space-y-3">
        <span className="block text-xs font-bold uppercase tracking-wider text-ink-500">Public leaderboard</span>
        <Switch
          checked={form.leaderboard_visible}
          onChange={(v) => setForm((f) => ({ ...f, leaderboard_visible: v }))}
          label="Show up on public leaderboards"
          description="Turn this off to keep your entries out of any tournament's public leaderboard. Private group leaderboards aren't affected."
        />
        {form.leaderboard_visible && (
          <Select
            label="Name shown on the leaderboard"
            value={form.leaderboard_name_mode}
            onChange={(e) => setForm((f) => ({ ...f, leaderboard_name_mode: e.target.value }))}
          >
            <option value="display_name">Display name ({form.display_name || 'not set'})</option>
            <option value="username">Username (@{form.username || 'not set'})</option>
          </Select>
        )}
      </motion.div>

      <motion.div variants={rise} className="flex justify-end">
        <Button type="submit" loading={mutation.isPending} disabled={!dirty}>
          <Save size={15} /> Save changes
        </Button>
      </motion.div>

      <motion.div variants={rise}>
        <BillingCard />
      </motion.div>
    </motion.form>
  )
}

/* ── Billing card ────────────────────────────────────────── */
function BillingCard() {
  const { data: status, isLoading } = useQuery({
    queryKey: ['billing', 'status'],
    queryFn: api.billingStatus,
  })

  const portalMutation = useMutation({
    mutationFn: () => api.billingPortal(window.location.origin + '/profile'),
    onSuccess: (res) => {
      window.location.href = res.portal_url
    },
    onError: (err) => toast.error('Could not open billing portal', { body: err.message }),
  })

  if (isLoading) return <Skeleton className="h-32 w-full" />

  const isAnnual = status?.plan === 'annual'

  return (
    <Card className="p-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="font-display text-sm uppercase tracking-wide text-ink-100">Billing</h3>
          <p className="mt-1 text-sm text-ink-400">
            {isAnnual ? (
              <>
                <span className="font-semibold text-gold-400">Annual plan</span> — unlimited entries and fantasy leagues.
              </>
            ) : (
              <>
                <span className="font-semibold text-ink-200">Free plan</span> —{' '}
                {status?.submissions_used ?? 0} / {status?.submissions_limit ?? 3} tournament entries used.
              </>
            )}
          </p>
        </div>
        {isAnnual ? (
          <Button variant="secondary" size="sm" onClick={() => portalMutation.mutate()} loading={portalMutation.isPending}>
            Manage billing
          </Button>
        ) : (
          <Link to="/pricing">
            <Button size="sm">
              <Crown size={14} /> Upgrade
            </Button>
          </Link>
        )}
      </div>
    </Card>
  )
}

/* ══ Stats tab ══════════════════════════════════════════ */
function StatsTab() {
  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['my-analytics'],
    queryFn: api.myAnalytics,
  })

  const stats = useMemo(() => {
    if (!data) return null
    const correct = data.correct ?? data.correct_pick_count ?? 0
    const scored = data.scored ?? data.scored_pick_count ?? 0
    const accuracy = normAcc(data.accuracy) ?? (scored > 0 ? correct / scored : null)
    const byWeight = (data.by_weight ?? []).map((w) => ({
      label: String(w.weight ?? w.name ?? w.weight_class ?? ''),
      value: normAcc(w.accuracy) ?? (w.scored > 0 ? (w.correct ?? 0) / w.scored : 0),
      detail: w.scored != null ? `${w.correct ?? 0}/${w.scored}` : undefined,
    }))
    const byRound = (data.by_round ?? []).map((r) => ({
      label: r.label ?? r.round_label ?? (r.round_number != null ? `Round ${r.round_number}` : ''),
      value: normAcc(r.accuracy) ?? (r.scored > 0 ? (r.correct ?? 0) / r.scored : 0),
      detail: r.scored != null ? `${r.correct ?? 0}/${r.scored}` : undefined,
    }))
    const byTournament = data.by_tournament ?? []
    const bestWeights = (data.most_successful_weights ?? []).map((w) =>
      typeof w === 'string' || typeof w === 'number' ? String(w) : String(w.weight ?? w.name ?? '')
    )
    return {
      correct, scored, accuracy,
      currentStreak: data.current_streak ?? 0,
      bestStreak: data.best_streak ?? 0,
      bestFinish: data.best_finish ?? null,
      avgPercentile: normAcc(data.avg_percentile),
      championAccuracy: normAcc(data.champion_accuracy),
      byWeight, byRound, byTournament, bestWeights,
    }
  }, [data])

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-24" />
          ))}
        </div>
        <Skeleton className="h-56 w-full" />
      </div>
    )
  }
  if (isError) {
    return (
      <EmptyState
        icon={<AlertTriangle size={26} />}
        title="Stats unavailable"
        body={error?.message}
        action={
          <Button onClick={() => refetch()} loading={isRefetching}>
            <RefreshCw size={15} /> Try again
          </Button>
        }
      />
    )
  }

  const empty = !stats || ((stats.scored ?? 0) === 0 && stats.byTournament.length === 0)
  if (empty) {
    return (
      <EmptyState
        icon={<BarChart3 size={26} />}
        title="No stats yet"
        body="Once your picks start getting scored, your accuracy, streaks, and finishes show up here."
      />
    )
  }

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="space-y-6">
      {/* donut + stat cards */}
      <motion.div variants={rise} className="grid items-start gap-4 lg:grid-cols-[320px_1fr]">
        <Card className="flex flex-col items-center p-6">
          <h3 className="mb-4 self-start font-display text-sm uppercase tracking-wide text-ink-100">Pick accuracy</h3>
          <Donut
            size={180}
            stroke={22}
            segments={[
              { value: stats.correct, color: 'var(--color-gold-500)', label: 'Correct' },
              { value: Math.max(0, (stats.scored ?? 0) - stats.correct), color: 'var(--color-mat-600)', label: 'Missed' },
            ]}
            center={
              <span className={cn('font-mono text-4xl font-bold', (stats.accuracy ?? 0) >= 0.6 ? 'text-gold-300' : 'text-ink-100')}>
                {stats.accuracy != null ? pct(stats.accuracy) : '—'}
              </span>
            }
            sub={`${stats.correct}/${stats.scored} correct`}
          />
          {stats.championAccuracy != null && (
            <p className="mt-4 text-xs text-ink-500">
              Champion picks: <span className="font-mono font-bold text-gold-400">{pct(stats.championAccuracy)}</span>
            </p>
          )}
        </Card>
        <div className="grid gap-4 sm:grid-cols-2">
          <Stat
            label="Best finish"
            value={stats.bestFinish != null ? `#${stats.bestFinish}` : '—'}
            sub="best tournament rank"
            icon={<Medal size={16} />}
          />
          <Stat
            label="Avg percentile"
            value={stats.avgPercentile != null ? `Top ${pct(stats.avgPercentile)}` : '—'}
            sub="across tournaments"
            icon={<TrendingUp size={16} />}
          />
          <Stat label="Current streak" value={stats.currentStreak} sub="correct picks in a row" icon={<Flame size={16} />} />
          <Stat label="Best streak" value={stats.bestStreak} sub="all time" icon={<Award size={16} />} />
        </div>
      </motion.div>

      {/* by weight / by round */}
      <motion.div variants={rise} className="grid items-start gap-4 lg:grid-cols-2">
        <Card className="p-5">
          <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Accuracy by weight</h3>
          <HBarList rows={stats.byWeight} color="gold" />
        </Card>
        <Card className="p-5">
          <h3 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Accuracy by round</h3>
          <HBarList rows={stats.byRound} color="pin" />
        </Card>
      </motion.div>

      {/* most successful weights */}
      {stats.bestWeights.length > 0 && (
        <motion.div variants={rise}>
          <Card className="p-5">
            <h3 className="mb-3 font-display text-sm uppercase tracking-wide text-ink-100">Your money weights</h3>
            <div className="flex flex-wrap gap-2">
              {stats.bestWeights.map((w) => (
                <Badge key={w} color="gold" className="px-3 py-1 font-mono text-xs normal-case">
                  {w}
                </Badge>
              ))}
            </div>
          </Card>
        </motion.div>
      )}

      {/* by tournament */}
      {stats.byTournament.length > 0 && (
        <motion.div variants={rise}>
          <Card className="overflow-hidden">
            <h3 className="px-5 pt-5 font-display text-sm uppercase tracking-wide text-ink-100">By tournament</h3>
            <div className="mt-3 overflow-x-auto">
              <table className="w-full min-w-[480px] border-collapse text-sm">
                <thead>
                  <tr className="border-y border-mat-700 text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
                    <th className="px-5 py-2.5">Tournament</th>
                    <th className="px-4 py-2.5 text-right">Accuracy</th>
                    <th className="px-4 py-2.5 text-right">Points</th>
                    <th className="px-5 py-2.5 text-right">Rank</th>
                  </tr>
                </thead>
                <tbody>
                  {stats.byTournament.map((t, i) => {
                    const acc = normAcc(t.accuracy) ?? (t.scored > 0 ? (t.correct ?? 0) / t.scored : null)
                    return (
                      <tr key={t.tournament_id ?? t.id ?? i} className="border-b border-mat-800 last:border-0">
                        <td className="px-5 py-3 font-semibold text-ink-100">
                          {t.name ?? t.tournament_name}
                          {t.year && <span className="ml-1.5 font-mono text-xs text-ink-500">{t.year}</span>}
                        </td>
                        <td className="px-4 py-3 text-right font-mono text-sm font-bold text-pin-400">{acc != null ? pct(acc) : '—'}</td>
                        <td className="px-4 py-3 text-right font-mono text-sm font-bold text-gold-400">{formatPoints(t.points ?? t.total_points)}</td>
                        <td className="px-5 py-3 text-right font-mono text-sm text-ink-200">{t.rank != null ? `#${t.rank}` : '—'}</td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </Card>
        </motion.div>
      )}
    </motion.div>
  )
}

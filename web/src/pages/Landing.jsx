import React, { useMemo } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion, useReducedMotion } from 'framer-motion'
import {
  ArrowRight,
  Trophy,
  GitBranch,
  TrendingUp,
  Sparkles,
  Scale,
  Crown,
} from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore } from '../lib/store'
import { Button, Card, CardSkeleton, EmptyState, SectionHeading, Avatar } from '../components/ui'
import TournamentCard from '../components/tournament/TournamentCard'
import { ErrorState } from '../components/tournament/Feedback'
import { normalizeList, displayName } from '../components/tournament/helpers'
import { cn, formatPoints } from '../lib/utils'

const SCHOOLS = [
  'Penn State', 'Iowa', 'Oklahoma State', 'Ohio State', 'Michigan', 'Cornell',
  'Nebraska', 'Arizona State', 'Missouri', 'Virginia Tech', 'NC State',
  'Minnesota', 'Wisconsin', 'Lehigh', 'Northern Iowa', 'Stanford',
]

const GRAIN =
  "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='0.4'/%3E%3C/svg%3E\")"

/* ── Animated bracket lines behind the hero ───────────── */
function buildBracketPaths() {
  const out = []
  const ys = Array.from({ length: 8 }, (_, i) => 60 + i * 72)
  const side = (xStart, dir) => {
    let level = ys
    let x = xStart
    const step = 150 * dir
    while (level.length > 1) {
      const next = []
      for (let i = 0; i < level.length; i += 2) {
        const a = level[i]
        const b = level[i + 1]
        const mid = (a + b) / 2
        const x1 = x + step
        const x2 = x + step * 2
        out.push({ d: `M ${x} ${a} H ${x1} V ${b} M ${x} ${b} H ${x1} M ${x1} ${mid} H ${x2}`, gold: i === 0 })
        next.push(mid)
      }
      level = next
      x = x2
    }
    return { y: level[0], x }
  }
  side(20, 1)
  side(1180, -1)
  out.push({ d: 'M 280 312 H 920', gold: true })
  return out
}

function BracketLines() {
  const reduce = useReducedMotion()
  const paths = useMemo(buildBracketPaths, [])
  return (
    <svg
      className="absolute inset-0 h-full w-full opacity-[0.16]"
      viewBox="0 0 1200 620"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
    >
      {paths.map((p, i) => (
        <motion.path
          key={i}
          d={p.d}
          fill="none"
          stroke={p.gold ? 'var(--color-gold-500)' : 'var(--color-mat-500)'}
          strokeWidth={p.gold ? 2 : 1.25}
          initial={reduce ? false : { pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={reduce ? { duration: 0 } : { duration: 1.4, delay: 0.2 + i * 0.05, ease: 'easeInOut' }}
        />
      ))}
      <motion.circle
        cx="600"
        cy="312"
        r="5"
        fill="var(--color-gold-500)"
        initial={reduce ? false : { scale: 0, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ delay: 2, duration: 0.4 }}
      />
    </svg>
  )
}

/* ── Mini mocks for "Two ways to play" ────────────────── */
function BracketMock() {
  const lines = [
    { d: 'M 56 12 H 63 V 36 M 56 36 H 63 M 63 24 H 70', gold: true },
    { d: 'M 56 60 H 63 V 84 M 56 84 H 63 M 63 72 H 70', gold: false },
    { d: 'M 126 24 H 133 V 72 M 126 72 H 133 M 133 48 H 140', gold: true },
  ]
  return (
    <svg viewBox="0 0 208 96" className="w-full" aria-hidden="true">
      {[
        { x: 0, y: 4, gold: true }, { x: 0, y: 28, gold: false }, { x: 0, y: 52, gold: false }, { x: 0, y: 76, gold: false },
        { x: 70, y: 16, gold: true }, { x: 70, y: 64, gold: false },
      ].map((r, i) => (
        <rect key={i} x={r.x} y={r.y} width="56" height="16" rx="3"
          fill="var(--color-mat-800)" stroke={r.gold ? 'var(--color-gold-500)' : 'var(--color-mat-600)'} strokeWidth="1" />
      ))}
      {lines.map((l, i) => (
        <path key={i} d={l.d} fill="none" stroke={l.gold ? 'var(--color-gold-500)' : 'var(--color-mat-600)'} strokeWidth="1.25" />
      ))}
      <rect x="140" y="40" width="64" height="18" rx="3" fill="var(--color-mat-800)" stroke="var(--color-gold-500)" strokeWidth="1.25" />
      <rect x="140" y="40" width="3" height="18" rx="1.5" fill="var(--color-gold-500)" />
      <text x="152" y="52" fill="var(--color-gold-300)" fontSize="8" fontFamily="JetBrains Mono, monospace" fontWeight="700">CHAMP</text>
    </svg>
  )
}

function PickemMock() {
  const rows = [
    { seed: 1, name: 'Starocci', cost: 130, w: '52%' },
    { seed: 2, name: 'Brooks', cost: 120, w: '46%' },
    { seed: 7, name: 'Contrarian pick', cost: 70, w: '30%' },
  ]
  return (
    <div aria-hidden="true">
      <div className="mb-1.5 flex items-center justify-between font-mono text-[10px] font-bold">
        <span className="text-ink-500">BUDGET</span>
        <span className="text-gold-400">640 / 1000</span>
      </div>
      <div className="mb-3 h-2 overflow-hidden rounded-full bg-mat-700">
        <div className="h-full rounded-full bg-gold-500" style={{ width: '64%' }} />
      </div>
      <div className="space-y-1.5">
        {rows.map((r) => (
          <div key={r.name} className="flex items-center gap-2 rounded-md border border-mat-700 bg-mat-800 px-2 py-1.5">
            <span className="flex h-5 w-5 items-center justify-center rounded bg-mat-700 font-mono text-[9px] font-bold text-gold-400">{r.seed}</span>
            <span className="min-w-0 flex-1 truncate text-[11px] font-semibold text-ink-200">{r.name}</span>
            <span className="font-mono text-[9px] font-bold text-ink-500">{r.cost} pts</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function PlayCard({ icon: Icon, title, copy, chips, mock, index }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-60px' }}
      transition={{ duration: 0.45, delay: index * 0.1, ease: [0.22, 1, 0.36, 1] }}
    >
      <Card hover className="flex h-full flex-col p-6">
        <div className="mb-4 flex items-center gap-3">
          <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-gold-500/12 text-gold-400">
            <Icon size={20} />
          </span>
          <h3 className="font-display text-base uppercase tracking-wide text-ink-100">{title}</h3>
        </div>
        <p className="text-sm leading-relaxed text-ink-400">{copy}</p>
        <div className="mt-5 rounded-lg border border-mat-700 bg-mat-900/70 p-4">{mock}</div>
        <div className="mt-4 flex flex-wrap gap-2">
          {chips.map((c) => (
            <span key={c} className="rounded-full border border-mat-600 bg-mat-800 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-ink-400">
              {c}
            </span>
          ))}
        </div>
      </Card>
    </motion.div>
  )
}

/* ── Page ─────────────────────────────────────────────── */
export default function Landing() {
  const token = useAuthStore((s) => s.token)
  const navigate = useNavigate()
  const ctaHref = token ? '/tournaments' : '/register'

  const openQ = useQuery({
    queryKey: ['tournaments', 'landing', 'open'],
    queryFn: () => api.tournaments({ status: 'open', per: 6 }),
    staleTime: 60000,
    retry: 1,
  })
  const liveQ = useQuery({
    queryKey: ['tournaments', 'landing', 'live'],
    queryFn: () => api.tournaments({ status: 'live', per: 6 }),
    staleTime: 60000,
    retry: 1,
  })

  const open = normalizeList(openQ.data)
  const live = normalizeList(liveQ.data)
  const cards = [...live.items, ...open.items].slice(0, 6)
  const flagship = live.items[0] ?? open.items[0]
  const loading = openQ.isLoading || liveQ.isLoading
  const failed = openQ.isError && liveQ.isError

  const lbQ = useQuery({
    queryKey: ['leaderboard', 'teaser', flagship?.id],
    queryFn: () => api.leaderboard(flagship.id, { per: 5 }),
    enabled: !!flagship?.id,
    staleTime: 60000,
    retry: 1,
  })
  const teaserRows = normalizeList(lbQ.data).items.slice(0, 5)

  const totals = {
    events: open.total + live.total,
    players: cards.reduce((a, t) => a + (t.entry_count ?? 0), 0),
    athletes: cards.reduce((a, t) => a + (t.competitor_count ?? 0), 0),
  }
  const showStats = !loading && (totals.events > 0 || totals.players > 0 || totals.athletes > 0)

  const scrollToHow = () => document.getElementById('how-it-works')?.scrollIntoView({ behavior: 'smooth' })

  return (
    <div className="-mt-6">
      {/* ── Hero ─────────────────────────────────────── */}
      <section className="relative left-1/2 w-screen -translate-x-1/2 overflow-hidden">
        <div className="bg-arena absolute inset-0" aria-hidden="true" />
        <BracketLines />
        <div className="pointer-events-none absolute inset-0 opacity-[0.05]" style={{ backgroundImage: GRAIN }} aria-hidden="true" />
        <div className="relative mx-auto flex min-h-[80vh] max-w-7xl flex-col items-center justify-center px-4 py-20 text-center">
          <motion.span
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="mb-6 inline-flex items-center gap-2 rounded-full border border-gold-500/30 bg-gold-500/10 px-4 py-1.5 text-[11px] font-bold uppercase tracking-[0.18em] text-gold-400"
          >
            <Sparkles size={13} /> Fantasy wrestling brackets
          </motion.span>
          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.1, ease: [0.22, 1, 0.36, 1] }}
            className="font-display text-[clamp(3rem,9vw,7.5rem)] uppercase leading-[0.95] tracking-tight text-ink-100"
          >
            Predict every
            <br />
            <span className="text-shimmer">match.</span>
          </motion.h1>
          <motion.p
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.55, delay: 0.25 }}
            className="mt-6 max-w-xl text-base text-ink-400 sm:text-lg"
          >
            Champions, blood rounds, buzzer-beater upsets. Call all 61 matches per weight and prove
            you know the mat better than anyone.
          </motion.p>
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.55, delay: 0.38 }}
            className="mt-9 flex flex-col gap-3 sm:flex-row"
          >
            <Button size="xl" onClick={() => navigate(ctaHref)}>
              Browse Tournaments <ArrowRight size={18} />
            </Button>
            <Button size="xl" variant="secondary" onClick={scrollToHow}>
              How it works
            </Button>
          </motion.div>

          {showStats && (
            <motion.dl
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.6, delay: 0.55 }}
              className="mt-14 grid grid-cols-3 gap-6 border-t border-mat-800 pt-8 sm:gap-12"
            >
              {[
                { label: 'Events in the arena', value: totals.events },
                { label: 'Players on the board', value: totals.players },
                { label: 'Athletes seeded', value: totals.athletes },
              ].map((s) => (
                <div key={s.label}>
                  <dd className="font-mono text-2xl font-bold text-ink-100 sm:text-3xl">{s.value}</dd>
                  <dt className="mt-1 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">{s.label}</dt>
                </div>
              ))}
            </motion.dl>
          )}
        </div>
      </section>

      {/* ── Live & open tournaments ──────────────────── */}
      <section className="py-16">
        <div className="flex items-end justify-between gap-4">
          <SectionHeading sub="Real brackets, real stakes. Jump in before the lock.">Live & open tournaments</SectionHeading>
          <Link
            to="/tournaments"
            className="mb-4 hidden shrink-0 items-center gap-1 text-sm font-bold text-gold-500 hover:text-gold-300 sm:inline-flex"
          >
            View all <ArrowRight size={14} />
          </Link>
        </div>
        {loading ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <CardSkeleton key={i} />
            ))}
          </div>
        ) : failed ? (
          <ErrorState
            error={openQ.error ?? liveQ.error}
            onRetry={() => {
              openQ.refetch()
              liveQ.refetch()
            }}
            title="Couldn't reach the arena"
          />
        ) : cards.length ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {cards.map((t, i) => (
              <TournamentCard key={t.id} tournament={t} index={i} />
            ))}
          </div>
        ) : (
          <EmptyState
            icon={<Trophy size={22} />}
            title="The first tournament is coming"
            body="We're seeding the brackets now. Create an account and you'll be first on the mat when entries open."
            action={<Button onClick={() => navigate(ctaHref)}>Get ready <ArrowRight size={15} /></Button>}
          />
        )}
      </section>

      {/* ── Two ways to play ─────────────────────────── */}
      <section className="py-16">
        <SectionHeading sub="Same tournament, two battlegrounds. Enter one — or both.">Two ways to play</SectionHeading>
        <div className="grid gap-5 lg:grid-cols-2">
          <PlayCard
            index={0}
            icon={GitBranch}
            title="Bracket Challenge"
            copy="Predict every match of every weight — first round through the finals, plus the consolation gauntlet. Winners advance through your bracket, and every correct call banks points."
            chips={['61 matches per weight', 'Champion bonuses', 'Blood rounds count']}
            mock={<BracketMock />}
          />
          <PlayCard
            index={1}
            icon={Scale}
            title="Pick'em Showdown"
            copy="Salary-cap wrestling. Build a stable of ten champions under the budget — spend big on a #1 seed or hunt contrarian value deep in the bracket. Tiebreakers settle the rest."
            chips={['1,000-point salary cap', 'One pick per weight', 'Tiebreaker drama']}
            mock={<PickemMock />}
          />
        </div>
      </section>

      {/* ── How it works ─────────────────────────────── */}
      <section id="how-it-works" className="scroll-mt-24 py-16">
        <SectionHeading sub="From first whistle to the final hand-raise.">How it works</SectionHeading>
        <div className="grid gap-5 md:grid-cols-3">
          {[
            {
              icon: Trophy,
              title: 'Pick your tournament',
              copy: 'NCAA championships, conference brackets, opens — if there’s a bracket, there’s a game waiting for you.',
            },
            {
              icon: GitBranch,
              title: 'Predict every match',
              copy: 'Champions, consolation comebacks, 3rd through 8th place — fill out the whole tree before the lock.',
            },
            {
              icon: TrendingUp,
              title: 'Climb the leaderboard',
              copy: 'Live scoring as results land. Out-pick your friends, your group, and the entire arena.',
            },
          ].map((s, i) => (
            <motion.div
              key={s.title}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: '-60px' }}
              transition={{ duration: 0.45, delay: i * 0.08, ease: [0.22, 1, 0.36, 1] }}
            >
              <Card className="relative h-full overflow-hidden p-6">
                <span className="absolute -right-1 -top-2 font-mono text-5xl font-bold text-mat-700" aria-hidden="true">
                  0{i + 1}
                </span>
                <div className="relative">
                  <span className="mb-4 flex h-11 w-11 items-center justify-center rounded-xl bg-gold-500/12 text-gold-400">
                    <s.icon size={20} />
                  </span>
                  <h3 className="font-display text-sm uppercase tracking-wide text-ink-100">{s.title}</h3>
                  <p className="mt-2 text-sm leading-relaxed text-ink-500">{s.copy}</p>
                </div>
              </Card>
            </motion.div>
          ))}
        </div>
      </section>

      {/* ── Leaderboard teaser ───────────────────────── */}
      {flagship && teaserRows.length > 0 && (
        <section className="py-16">
          <SectionHeading sub={`${flagship.name} — top of the table right now`}>The chase for gold</SectionHeading>
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.45 }}
          >
            <Card className="overflow-hidden">
              {teaserRows.map((row, i) => (
                <div key={row.id ?? row.user?.id ?? i} className="flex items-center gap-4 border-t border-mat-700/60 px-5 py-3.5 first:border-t-0">
                  <span
                    className={cn(
                      'flex w-7 shrink-0 items-center justify-center font-mono text-sm font-bold',
                      i === 0 ? 'text-gold-400' : 'text-ink-500'
                    )}
                  >
                    {i === 0 ? <Crown size={15} /> : i + 1}
                  </span>
                  <Avatar user={row.user} size="sm" />
                  <span className="min-w-0 flex-1 truncate text-sm font-semibold text-ink-100">{displayName(row.user)}</span>
                  <span className="font-mono text-sm font-bold text-gold-400">{formatPoints(row.total_points)}</span>
                </div>
              ))}
              <Link
                to={`/tournaments/${flagship.slug ?? flagship.id}?tab=leaderboard`}
                className="block border-t border-mat-700 bg-mat-900/40 px-5 py-3 text-center text-xs font-bold uppercase tracking-[0.14em] text-gold-500 transition-colors hover:text-gold-300"
              >
                Full leaderboard →
              </Link>
            </Card>
          </motion.div>
        </section>
      )}

      {/* ── School marquee ───────────────────────────── */}
      <section
        aria-label="Schools on the mat"
        className="relative left-1/2 w-screen -translate-x-1/2 overflow-hidden border-y border-mat-800 bg-mat-900/60 py-4"
      >
        <div className="animate-marquee flex w-max gap-8">
          {[...SCHOOLS, ...SCHOOLS].map((s, i) => (
            <span
              key={i}
              aria-hidden={i >= SCHOOLS.length}
              className="flex items-center gap-8 whitespace-nowrap font-display text-sm uppercase tracking-widest text-ink-600"
            >
              {s} <span className="text-gold-500/50">•</span>
            </span>
          ))}
        </div>
      </section>

      {/* ── Final CTA band ───────────────────────────── */}
      <section className="relative left-1/2 w-screen -translate-x-1/2 overflow-hidden">
        <div className="bg-arena absolute inset-0" aria-hidden="true" />
        <div className="relative mx-auto max-w-7xl px-4 py-20 text-center">
          <motion.h2
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="font-display text-3xl uppercase tracking-tight text-ink-100 sm:text-5xl"
          >
            The mat is <span className="text-shimmer">calling.</span>
          </motion.h2>
          <motion.p
            initial={{ opacity: 0, y: 12 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="mx-auto mt-4 max-w-md text-ink-400"
          >
            Free to play. Bragging rights forever. Lock your picks before the first whistle.
          </motion.p>
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="mt-8"
          >
            <Button size="xl" onClick={() => navigate(ctaHref)}>
              {token ? 'Browse Tournaments' : 'Join the mat — it’s free'} <ArrowRight size={18} />
            </Button>
          </motion.div>
        </div>
      </section>
    </div>
  )
}

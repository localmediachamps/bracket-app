import React, { useMemo } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion, useReducedMotion } from 'framer-motion'
import {
  ArrowRight,
  Trophy,
  GitBranch,
  Sparkles,
  Scale,
  Crown,
  ScrollText,
  Swords,
} from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore } from '../lib/store'
import { Button, Card, CardSkeleton, EmptyState, SectionHeading, Avatar } from '../components/ui'
import TournamentCard from '../components/tournament/TournamentCard'
import { ErrorState } from '../components/tournament/Feedback'
import { normalizeList, displayName } from '../components/tournament/helpers'
import { cn, formatPoints, victoryLabel } from '../lib/utils'

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
    // 3 halving levels (8→4→2→1); step*2*3 must land short of center (600)
    // on both sides so the two brackets meet cleanly instead of overshooting
    // past each other.
    const step = 80 * dir
    while (level.length > 1) {
      const next = []
      for (let i = 0; i < level.length; i += 2) {
        const a = level[i]
        const b = level[i + 1]
        const mid = (a + b) / 2
        const xA = x + step
        const xB = x + step * 2
        out.push({ d: `M ${x} ${a} H ${xA} V ${b} M ${x} ${b} H ${xA} M ${xA} ${mid} H ${xB}`, gold: i === 0 })
        next.push(mid)
      }
      level = next
      x += step * 2
    }
    return { y: level[0], x }
  }
  const left = side(20, 1)
  const right = side(1180, -1)
  // Bridge the two sides' actual convergence points (finals) instead of a
  // hardcoded span that no longer matches once the geometry above changes.
  out.push({ d: `M ${left.x} ${left.y} H ${right.x}`, gold: true })
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
  // Costs match the real seed-cost table (seed 1 = 200 down to a flat 10 for
  // unseeded) - illustrating why a full lineup of favorites is impossible.
  const rows = [
    { seed: 1, name: 'Starocci', cost: 200 },
    { seed: 4, name: 'Hamiti', cost: 120 },
    { seed: 9, name: 'Contrarian pick', cost: 60 },
    { seed: 14, name: 'Deep sleeper', cost: 20 },
  ]
  const spent = rows.reduce((s, r) => s + r.cost, 0)
  return (
    <div aria-hidden="true">
      <div className="mb-1.5 flex items-center justify-between font-mono text-[10px] font-bold">
        <span className="text-ink-500">BUDGET (4 OF 10 PICKS)</span>
        <span className="text-gold-400">{spent} / 1000</span>
      </div>
      <div className="mb-3 h-2 overflow-hidden rounded-full bg-mat-700">
        <div className="h-full rounded-full bg-gold-500" style={{ width: `${Math.min(100, (spent / 1000) * 100)}%` }} />
      </div>
      <div className="space-y-1.5">
        {rows.map((r) => (
          <div key={r.name} className="flex items-center gap-2 rounded-md border border-mat-700 bg-mat-800 px-2 py-1.5">
            <span className="flex h-5 w-5 items-center justify-center rounded bg-mat-700 font-mono text-[9px] font-bold text-gold-400">{r.seed}</span>
            <span className="min-w-0 flex-1 truncate text-[11px] font-semibold text-ink-200">{r.name}</span>
            <span className="font-mono text-[9px] font-bold text-ink-500">{r.cost}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function FantasyMock() {
  const you = { name: 'Iron Range WC', score: 34.2 }
  const opp = { name: 'The Cradle Crew', score: 28.9 }
  const total = you.score + opp.score
  const youPct = Math.round((you.score / total) * 100)
  const rows = [
    { weight: 125, name: 'J. Martinez', pts: 6.4, side: 'you' },
    { weight: 133, name: 'T. Owens', pts: 9.0, side: 'you' },
    { weight: 141, name: 'D. Guanajuato', pts: 4.5, side: 'you' },
    { weight: 149, name: 'R. Diaz', pts: 7.5, side: 'opp' },
    { weight: 157, name: 'K. Foster', pts: 5.0, side: 'opp' },
  ]
  return (
    <div aria-hidden="true">
      <div className="mb-3 flex items-center justify-between">
        <span className="font-display text-xs uppercase tracking-wide text-ink-200">Week 6 · Head-to-head</span>
        <span className="rounded-full border border-gold-500/30 bg-gold-500/10 px-2 py-0.5 font-mono text-[10px] font-bold text-gold-400">Live</span>
      </div>

      <div className="rounded-lg border border-mat-700 bg-mat-800/60 p-3">
        <div className="flex items-center justify-between text-xs font-bold text-ink-100">
          <span className="truncate">{you.name}</span>
          <span className="truncate text-ink-500">{opp.name}</span>
        </div>
        <div className="mt-1 flex items-center justify-between font-mono text-2xl font-bold">
          <span className="text-gold-400">{you.score}</span>
          <span className="text-ink-500">{opp.score}</span>
        </div>
        <div className="mt-2 flex h-1.5 overflow-hidden rounded-full bg-mat-700">
          <div className="h-full bg-gold-500" style={{ width: `${youPct}%` }} />
          <div className="h-full bg-mat-500" style={{ width: `${100 - youPct}%` }} />
        </div>
      </div>

      <div className="mb-1.5 mt-4 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-600">This week's top scorers</div>
      <div className="space-y-1.5">
        {rows.map((r) => (
          <div key={r.weight} className="flex items-center gap-2 rounded-md border border-mat-700 bg-mat-800 px-2 py-1.5">
            <span className="flex h-5 w-9 items-center justify-center rounded bg-mat-700 font-mono text-[9px] font-bold text-gold-400">{r.weight}</span>
            <span className="min-w-0 flex-1 truncate text-[11px] font-semibold text-ink-200">{r.name}</span>
            <span className={cn('font-mono text-[9px] font-bold', r.side === 'you' ? 'text-pin-400' : 'text-ink-500')}>+{r.pts}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

/* Small numbered "how this mode works" list, shared by PlayCard/SpotlightCard */
function HowSteps({ steps, label }) {
  if (!steps?.length) return null
  return (
    <div className="mt-4">
      {label && <div className="mb-1.5 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-600">{label}</div>}
      <ol className="space-y-2">
        {steps.map((s, i) => (
          <li key={i} className="flex items-start gap-2.5 text-xs leading-relaxed text-ink-400">
            <span className="mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-gold-500/15 font-mono text-[9px] font-bold text-gold-400">
              {i + 1}
            </span>
            <span>{s}</span>
          </li>
        ))}
      </ol>
    </div>
  )
}

function PlayCard({ icon: Icon, title, copy, steps, stepsLabel, chips, mock, index }) {
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
        <HowSteps steps={steps} label={stepsLabel} />
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

// The season league is a bigger commitment than the other two (a whole
// season of team-building, not a one-off entry) - it gets its own wider,
// more explanatory treatment rather than being squeezed into the same
// half-width card shape.
function SpotlightCard({ icon: Icon, eyebrow, title, copy, steps, chips, mock, cta, ctaHref }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-60px' }}
      transition={{ duration: 0.5 }}
    >
      <Card className="overflow-hidden border-gold-500/40 p-0 shadow-glow-sm">
        <div className="grid gap-0 lg:grid-cols-[1.15fr_1fr]">
          <div className="p-6 sm:p-8">
            <span className="mb-3 inline-flex items-center gap-2 rounded-full border border-gold-500/30 bg-gold-500/10 px-3 py-1 text-[10px] font-bold uppercase tracking-[0.16em] text-gold-400">
              <Icon size={12} /> {eyebrow}
            </span>
            <h3 className="font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">{title}</h3>
            <p className="mt-3 text-sm leading-relaxed text-ink-400">{copy}</p>
            <HowSteps steps={steps} label="How it works" />
            <div className="mt-5 flex flex-wrap gap-2">
              {chips.map((c) => (
                <span key={c} className="rounded-full border border-mat-600 bg-mat-800 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-ink-400">
                  {c}
                </span>
              ))}
            </div>
            <Link to={ctaHref} className="mt-6 inline-block">
              <Button>
                {cta} <ArrowRight size={15} />
              </Button>
            </Link>
          </div>
          <div className="border-t border-mat-700 bg-mat-900/70 p-6 sm:p-8 lg:border-l lg:border-t-0">{mock}</div>
        </div>
      </Card>
    </motion.div>
  )
}

function ResultsPreviewRow({ m, index }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.3, delay: index * 0.05 }}
      className="flex items-center gap-3 border-t border-mat-700/60 px-5 py-3.5 first:border-t-0 sm:gap-4"
    >
      <span className="w-11 shrink-0 font-mono text-[10px] font-bold uppercase tracking-wider text-gold-400">
        {m.weight_class || '—'}
      </span>
      <span className="min-w-0 flex-1 truncate text-sm">
        <span className="font-semibold text-ink-100">{m.winner_name_raw}</span>
        <span className="text-ink-600"> def. </span>
        <span className="text-ink-400">{m.loser_name_raw || 'opponent'}</span>
      </span>
      <span className="hidden shrink-0 max-w-[160px] truncate text-xs text-ink-500 md:block">{m.event_name}</span>
      <span className="shrink-0 font-mono text-[10px] font-bold uppercase tracking-wider text-ink-500">
        {victoryLabel(m.victory_type) || m.victory_type || '—'}
      </span>
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

  const resultsPreviewQ = useQuery({
    queryKey: ['results', 'landing-preview'],
    queryFn: () => api.searchResults({ per: 5 }),
    staleTime: 60000,
    retry: 1,
  })
  const resultsPreview = resultsPreviewQ.data?.items ?? []

  const scrollToWaysToPlay = () => document.getElementById('ways-to-play')?.scrollIntoView({ behavior: 'smooth' })

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
            Wrestling fantasy perfected. Predict a bracket, build a pick'em team, or draft a
            season-long league — and prove you know the mat better than anyone.
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
            <Button size="xl" variant="secondary" onClick={scrollToWaysToPlay}>
              Ways to play
            </Button>
          </motion.div>
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

      {/* ── Ways to play ──────────────────────────────── */}
      <section id="ways-to-play" className="scroll-mt-24 py-16">
        <SectionHeading sub="Jump into a single tournament in minutes, or go the distance for a whole season.">
          Ways to Play
        </SectionHeading>
        <div className="grid gap-5 lg:grid-cols-2">
          <PlayCard
            index={0}
            icon={GitBranch}
            title="Bracket Challenge"
            copy="Predict every match of every weight — first round through the finals, plus the consolation gauntlet. Fill it out before the lock, then watch it score live as real results land."
            steps={[
              'Every correct pick scores by round — 1 point in round one, up to 32 for the championship — so the deeper you predict correctly, the more it\'s worth',
              'How they win adds points on top, dual-meet style: a decision is 3, major decision 4, tech fall 5, and a fall is 6 — so a pin in the finals is worth far more than a decision in round one',
              'The consolation bracket and placement matches (3rd, 5th, 7th) score too, not just the title side',
            ]}
            stepsLabel="How scoring works"
            chips={['Any bracket size', 'Full consolation support', 'Every round counts']}
            mock={<BracketMock />}
          />
          <PlayCard
            index={1}
            icon={Scale}
            title="Pick'em Showdown"
            copy="Salary-cap wrestling. Draft one wrestler per weight class, priced by seed — a #1 costs far more than a #7. A lineup of favorites blows the budget by pick three, so winning teams are usually built on mid-pack wrestlers who outperform their seed, not a stable of champions."
            steps={[
              'Every wrestler scores points for each win, plus a bonus for how they win — a fall, tech fall, or major decision',
              'Where each one finally places (1st through 8th) adds points on top — a champion is worth the most, but a low seed who makes the podium can outscore a #1 who doesn\'t',
            ]}
            stepsLabel="How scoring works"
            chips={['1,000-point salary cap', 'One pick per weight', 'Tiebreaker drama']}
            mock={<PickemMock />}
          />
        </div>

        <div className="mt-5">
          <SpotlightCard
            icon={Swords}
            eyebrow="The deep game"
            title="Season-Long Fantasy League"
            copy="Form a league with your friends — as many as you want, though 6 to 8 is the sweet spot. Hold a snake draft to build your roster from the entire NCAA D1 field, then play out the whole season: weekly head-to-head matchups against another league member, plus a handful of marquee tournaments where the whole league competes on the same event at once."
            steps={[
              'Form a league and invite your friends, then snake draft the entire D1 field to build your roster',
              'Every week, set your active lineup and face another league member head-to-head',
              'A few marquee tournaments during the season have the whole league playing the same event at once',
              'Bowl season and the NCAA finals decide the champion',
            ]}
            chips={['Snake draft', 'Weekly head-to-head', 'Everyone-plays tournaments', 'Bowl season & NCAAs']}
            mock={<FantasyMock />}
            cta="Start a league"
            ctaHref={token ? '/leagues' : '/register'}
          />
        </div>
      </section>

      {/* ── Results library ───────────────────────────── */}
      <section className="py-16">
        <SectionHeading sub="Every real match, searchable — score, time, and how it ended.">The Results Library</SectionHeading>
        {resultsPreviewQ.isLoading ? (
          <CardSkeleton />
        ) : resultsPreview.length > 0 ? (
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.45 }}
          >
            <Card className="overflow-hidden">
              {resultsPreview.map((m, i) => (
                <ResultsPreviewRow key={m.id ?? m.source_match_id ?? i} m={m} index={i} />
              ))}
              <Link
                to="/results"
                className="block border-t border-mat-700 bg-mat-900/40 px-5 py-3 text-center text-xs font-bold uppercase tracking-[0.14em] text-gold-500 transition-colors hover:text-gold-300"
              >
                Explore the full library →
              </Link>
            </Card>
          </motion.div>
        ) : (
          <EmptyState
            icon={<ScrollText size={22} />}
            title="Building the archive"
            body="Real match results are on their way."
          />
        )}
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

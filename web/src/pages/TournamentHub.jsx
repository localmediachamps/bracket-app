import React, { useRef } from 'react'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import {
  Calendar,
  MapPin,
  Layers,
  Swords,
  Users,
  GitBranch,
  Trophy,
  Percent,
  CheckCircle2,
  Lock,
  Scale,
  SearchX,
} from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore } from '../lib/store'
import { Button, Countdown, EmptyState, Skeleton, StatusPill, Tabs } from '../components/ui'
import BracketPanel from '../components/tournament/BracketPanel'
import LeaderboardPanel from '../components/tournament/LeaderboardPanel'
import PickPopularityPanel from '../components/tournament/PickPopularityPanel'
import ResultsPanel from '../components/tournament/ResultsPanel'
import GroupsPanel from '../components/tournament/GroupsPanel'
import { ErrorState } from '../components/tournament/Feedback'
import { asModes } from '../components/tournament/helpers'
import { formatDate, plural } from '../lib/utils'

function HeaderSkeleton() {
  return (
    <div aria-busy="true" aria-label="Loading tournament">
      <Skeleton className="h-6 w-24" />
      <Skeleton className="mt-3 h-9 w-2/3 max-w-md" />
      <Skeleton className="mt-3 h-4 w-1/2 max-w-sm" />
      <div className="mt-6 flex gap-2">
        {Array.from({ length: 5 }).map((_, i) => (
          <Skeleton key={i} className="h-9 w-24" />
        ))}
      </div>
      <Skeleton className="mt-6 h-[420px] w-full rounded-xl" />
    </div>
  )
}

export default function TournamentHub() {
  const { slug } = useParams()
  const [searchParams, setSearchParams] = useSearchParams()
  const navigate = useNavigate()
  const user = useAuthStore((s) => s.user)
  const tabsRef = useRef(null)
  const tab = searchParams.get('tab') || 'bracket'

  const setTab = (key) => {
    const p = new URLSearchParams(searchParams)
    p.set('tab', key)
    setSearchParams(p, { replace: true })
  }

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['tournament', slug],
    queryFn: () => api.tournament(slug),
    retry: (count, e) => (e?.status === 404 || e?.status === 403 ? false : count < 2),
    staleTime: 30000,
  })

  if (isLoading) return <HeaderSkeleton />

  if (isError) {
    if (error?.status === 404) {
      return (
        <EmptyState
          icon={<SearchX size={22} />}
          title="Tournament not found"
          body="This bracket may have been moved, renamed, or never existed at all."
          action={<Button onClick={() => navigate('/tournaments')}>Browse tournaments</Button>}
        />
      )
    }
    if (error?.status === 403) {
      return (
        <EmptyState
          icon={<Lock size={22} />}
          title="This tournament is private"
          body="You don't have access to view this tournament yet."
          action={<Button variant="secondary" onClick={() => navigate('/tournaments')}>Browse tournaments</Button>}
        />
      )
    }
    return <ErrorState error={error} onRetry={refetch} title="Tournament failed to load" />
  }

  const t = data ?? {}
  const weights = t.weight_classes ?? t.weights ?? []
  const modes = asModes(t.game_modes)
  const myEntry = t.my_entry ?? null
  const competitorCount =
    t.competitor_count ?? (weights.length ? weights.reduce((a, w) => a + (w.competitor_count ?? 0), 0) : null)

  // Draft-ish tournaments aren't viewable by non-admins
  if (['draft', 'importing', 'needs_review'].includes(t.status) && !user?.is_admin) {
    return (
      <EmptyState
        icon={<Lock size={22} />}
        title="Not public yet"
        body="This tournament is still being built. Check back once it's published."
        action={<Button variant="secondary" onClick={() => navigate('/tournaments')}>Browse tournaments</Button>}
      />
    )
  }

  const dateRange =
    t.start_date || t.end_date
      ? `${formatDate(t.start_date, { year: undefined })} – ${formatDate(t.end_date, { year: undefined })}`
      : null

  const goPredict = () => navigate(`/tournaments/${t.slug ?? slug}/predict`)
  const goPickem = () => navigate(`/tournaments/${t.slug ?? slug}/pickem`)
  const viewBracket = () => {
    setTab('bracket')
    tabsRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  const ctas = []
  if (t.status === 'open') {
    ctas.push(
      <Button key="predict" size="lg" onClick={goPredict}>
        <GitBranch size={16} /> {myEntry ? 'Continue Picks' : 'Make Your Picks'}
      </Button>
    )
    if (modes.includes('pickem')) {
      ctas.push(
        <Button key="pickem" size="lg" variant="secondary" onClick={goPickem}>
          <Scale size={16} /> Pick'em
        </Button>
      )
    }
  } else if (t.status === 'locked' || t.status === 'live') {
    ctas.push(
      <Button key="bracket" size="lg" onClick={viewBracket}>
        <GitBranch size={16} /> View Bracket
      </Button>
    )
  } else if (t.status === 'completed') {
    ctas.push(
      <Button key="results" size="lg" variant="secondary" onClick={() => setTab('results')}>
        <CheckCircle2 size={16} /> Final Results
      </Button>
    )
  }

  const tabs = [
    { key: 'bracket', label: 'Bracket', icon: <GitBranch size={15} /> },
    { key: 'leaderboard', label: 'Leaderboard', icon: <Trophy size={15} /> },
    { key: 'picks', label: 'Picks %', icon: <Percent size={15} /> },
    { key: 'results', label: 'Results', icon: <CheckCircle2 size={15} /> },
    { key: 'groups', label: 'Groups', icon: <Users size={15} />, count: t.group_count || undefined },
  ]

  return (
    <div>
      {/* ── Header ─────────────────────────────────────── */}
      <motion.div
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
        className="mb-6 flex flex-wrap items-start justify-between gap-5"
      >
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-3">
            <StatusPill status={t.status} />
            {t.year && <span className="font-mono text-sm text-ink-500">{t.year}</span>}
          </div>
          <h1 className="mt-2 font-display text-2xl uppercase leading-tight tracking-tight text-ink-100 sm:text-3xl">
            {t.name}
          </h1>
          <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1.5 text-sm text-ink-500">
            {dateRange && (
              <span className="inline-flex items-center gap-1.5">
                <Calendar size={14} className="text-gold-500/70" /> {dateRange}
              </span>
            )}
            {t.location && (
              <span className="inline-flex items-center gap-1.5">
                <MapPin size={14} className="text-gold-500/70" /> {t.location}
              </span>
            )}
            <span className="inline-flex items-center gap-1.5">
              <Layers size={14} className="text-gold-500/70" /> {plural(weights.length, 'weight class', 'weight classes')}
            </span>
            {competitorCount != null && competitorCount > 0 && (
              <span className="inline-flex items-center gap-1.5">
                <Swords size={14} className="text-gold-500/70" /> {plural(competitorCount, 'competitor')}
              </span>
            )}
            <span className="inline-flex items-center gap-1.5">
              <Users size={14} className="text-gold-500/70" /> {plural(t.entry_count ?? 0, 'player')}
            </span>
          </div>
        </div>

        <div className="flex flex-col items-start gap-3 sm:items-end">
          {t.status === 'open' && t.locks_at && (
            <div className="rounded-xl border border-mat-700 bg-mat-850 px-4 py-2.5 sm:text-right">
              <span className="block text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">Picks lock in</span>
              <Countdown to={t.locks_at} className="text-lg" />
            </div>
          )}
          {ctas.length > 0 && <div className="flex flex-wrap gap-2">{ctas}</div>}
        </div>
      </motion.div>

      {/* ── Tabs ───────────────────────────────────────── */}
      <div ref={tabsRef} className="scroll-mt-20">
        <Tabs tabs={tabs} active={tab} onChange={setTab} />
      </div>

      <motion.div
        key={tab}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.25, ease: 'easeOut' }}
        className="pt-6"
      >
        {tab === 'bracket' && <BracketPanel tournament={t} weights={weights} myEntry={myEntry} />}
        {tab === 'leaderboard' && <LeaderboardPanel tournament={t} />}
        {tab === 'picks' && <PickPopularityPanel tournament={t} weights={weights} />}
        {tab === 'results' && <ResultsPanel tournament={t} weights={weights} />}
        {tab === 'groups' && <GroupsPanel tournament={t} />}
      </motion.div>
    </div>
  )
}

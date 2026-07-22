import React from 'react'
import { Link, useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { User, GraduationCap, CalendarDays, Trophy, Medal, GitBranch, Scale, Swords, Eye, EyeOff } from 'lucide-react'
import { api } from '../lib/api'
import { Avatar, Badge, Card, EmptyState, Skeleton, Stat } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { displayName, percentOf } from '../components/tournament/helpers'
import { formatDate, formatPoints } from '../lib/utils'

function entryViewPath(sourceType, entryId) {
  if (sourceType === 'pickem') return `/pickem-entries/${entryId}`
  if (sourceType === 'dual_meet') return `/dual-meet-entries/${entryId}`
  return `/entries/${entryId}/review`
}

function ProfileSkeleton() {
  return (
    <div className="space-y-5" aria-busy="true" aria-label="Loading profile">
      <Skeleton className="h-44 w-full" />
      <div className="grid grid-cols-3 gap-4">
        <Skeleton className="h-20" />
        <Skeleton className="h-20" />
        <Skeleton className="h-20" />
      </div>
      <Skeleton className="h-56 w-full" />
    </div>
  )
}

export default function UserProfile() {
  const { id } = useParams()
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['user-profile', id],
    queryFn: () => api.userProfile(id),
    retry: (count, e) => (e?.status === 404 ? false : count < 2),
    staleTime: 60000,
  })

  if (isLoading) return <ProfileSkeleton />

  if (isError) {
    if (error?.status === 404) {
      return (
        <EmptyState
          icon={<User size={22} />}
          title="Profile not found"
          body="This wrestler slipped out of the bracket — the profile doesn't exist or isn't public."
        />
      )
    }
    return <ErrorState error={error} onRetry={refetch} title="Profile failed to load" />
  }

  const profile = data?.user ?? data ?? {}
  const stats = data?.stats ?? {}
  const finishes = data?.finishes ?? data?.recent_finishes ?? []
  const submissions = data?.submissions ?? []
  const submissionsVisible = data?.submissions_visible ?? true
  const name = displayName(profile)
  const acc = percentOf(stats.avg_accuracy ?? stats.accuracy)
  const entries = stats.entries ?? stats.total_entries ?? (finishes.length || null)
  const bestRank = stats.best_rank ?? stats.best_finish

  return (
    <div className="mx-auto max-w-3xl">
      {/* ── Header card ────────────────────────────────── */}
      <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }}>
        <Card className="relative overflow-hidden p-6 sm:p-8">
          <div className="bg-arena absolute inset-0" aria-hidden="true" />
          <div className="relative flex flex-col items-start gap-5 sm:flex-row sm:items-center">
            <Avatar user={profile} size="xl" ring />
            <div className="min-w-0 flex-1">
              <h1 className="font-display text-2xl uppercase tracking-tight text-ink-100">{name}</h1>
              {profile.username && <p className="mt-0.5 font-mono text-sm text-ink-500">@{profile.username}</p>}
              {profile.bio && <p className="mt-3 max-w-lg text-sm leading-relaxed text-ink-300">{profile.bio}</p>}
              <div className="mt-4 flex flex-wrap items-center gap-2">
                {profile.favorite_school && (
                  <Badge color="gold">
                    <GraduationCap size={11} /> {profile.favorite_school}
                  </Badge>
                )}
                {profile.created_at && (
                  <Badge color="ink">
                    <CalendarDays size={11} /> On the mat since {formatDate(profile.created_at, { month: 'long', day: undefined })}
                  </Badge>
                )}
              </div>
            </div>
          </div>
        </Card>
      </motion.div>

      {/* ── Stats ──────────────────────────────────────── */}
      <motion.div
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.08 }}
        className="mt-5 grid grid-cols-3 gap-4"
      >
        <Stat label="Entries" value={entries ?? '—'} icon={<Trophy size={14} />} />
        <Stat label="Best rank" value={bestRank != null ? `#${bestRank}` : '—'} icon={<Medal size={14} />} />
        <Stat label="Avg accuracy" value={acc != null ? `${Math.round(acc)}%` : '—'} />
      </motion.div>

      {/* ── Recent finishes ────────────────────────────── */}
      <motion.div
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.16 }}
        className="mt-5"
      >
        <h2 className="mb-3 font-display text-sm uppercase tracking-wide text-ink-100">Recent finishes</h2>
        {finishes.length === 0 ? (
          <EmptyState
            icon={<Trophy size={22} />}
            title="No finishes yet"
            body={`${name} hasn't finished a tournament yet — the chase begins soon.`}
          />
        ) : (
          <Card className="overflow-hidden">
            {finishes.map((f, i) => {
              const tName = f.tournament_name ?? f.name ?? 'Tournament'
              const tSlug = f.tournament_slug ?? f.slug
              const rank = f.rank ?? f.final_rank
              const points = f.total_points ?? f.points
              const inner = (
                <div className="flex items-center gap-4 px-5 py-3.5">
                  <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-mat-800 text-gold-500">
                    <Trophy size={15} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ink-100">{tName}</p>
                    {f.year && <p className="font-mono text-xs text-ink-500">{f.year}</p>}
                  </div>
                  {points != null && <span className="font-mono text-sm font-bold text-ink-300">{formatPoints(points)} pts</span>}
                  {rank != null && (
                    <Badge color={rank <= 3 ? 'gold' : 'ink'}>#{rank}</Badge>
                  )}
                </div>
              )
              return (
                <div key={f.tournament_id ?? f.id ?? i} className="border-t border-mat-700/60 first:border-t-0">
                  {tSlug ? (
                    <Link to={`/tournaments/${tSlug}`} className="block transition-colors hover:bg-mat-800/50">
                      {inner}
                    </Link>
                  ) : (
                    inner
                  )}
                </div>
              )
            })}
          </Card>
        )}
      </motion.div>

      {/* ── Public submissions ───────────────────────────── */}
      <motion.div
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.22 }}
        className="mt-5"
      >
        <h2 className="mb-3 font-display text-sm uppercase tracking-wide text-ink-100">Public submissions</h2>
        {!submissionsVisible ? (
          <EmptyState
            icon={<EyeOff size={20} />}
            title="Kept private"
            body={`${name} keeps their submissions private.`}
          />
        ) : submissions.length === 0 ? (
          <EmptyState
            icon={<GitBranch size={20} />}
            title="Nothing public yet"
            body={`${name} hasn't made any bracket or pick'em entries public.`}
          />
        ) : (
          <Card className="overflow-hidden">
            {submissions.map((s, i) => {
              const ModeIcon = s.source_type === 'pickem' ? Scale : s.source_type === 'dual_meet' ? Swords : GitBranch
              const modeLabel = s.source_type === 'dual_meet' ? 'Dual meet' : s.source_type === 'pickem' ? 'Pick\'em' : 'Bracket'
              const inner = (
                <div className="flex items-center gap-4 px-5 py-3.5">
                  <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-mat-800 text-gold-500">
                    <ModeIcon size={15} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ink-100">{s.tournament_name ?? 'Tournament'}</p>
                    <div className="mt-0.5 flex items-center gap-2 text-xs text-ink-500">
                      <span>{modeLabel}</span>
                      {s.tournament_year && <span className="font-mono">{s.tournament_year}</span>}
                      {s.rank != null && <span>#{s.rank} in event</span>}
                    </div>
                  </div>
                  {s.platform_points != null && (
                    <span className="shrink-0 text-right">
                      <span className="block font-mono text-sm font-bold text-gold-400">+{formatPoints(s.platform_points)}</span>
                      <span className="block text-[10px] font-bold uppercase tracking-wider text-ink-600">to leaderboard</span>
                    </span>
                  )}
                  <Eye size={14} className="shrink-0 text-ink-500" />
                </div>
              )
              return (
                <div key={`${s.source_type}-${s.entry_id ?? i}`} className="border-t border-mat-700/60 first:border-t-0">
                  <Link to={entryViewPath(s.source_type, s.entry_id)} className="block transition-colors hover:bg-mat-800/50">
                    {inner}
                  </Link>
                </div>
              )
            })}
          </Card>
        )}
      </motion.div>
    </div>
  )
}

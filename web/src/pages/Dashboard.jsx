import React from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import {
  Flame, Clock, PencilLine, Eye, GitBranch, Trophy, Users, Bell,
  AlertTriangle, ChevronRight, RefreshCw, Target,
} from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore } from '../lib/store'
import {
  Card, StatusPill, Button, ProgressRing, Skeleton, EmptyState, Countdown, SectionHeading, Badge,
} from '../components/ui'
import { cn, formatPoints, formatDateTime, plural } from '../lib/utils'
import AnimatedNumber from '../components/profile/AnimatedNumber'
import GroupCard from '../components/groups/GroupCard'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

// me/dashboard's rows are shaped {entry, tournament, progress, rank} - the
// raw user_bracket/pickem_entry fields (id, status, total_points,
// possible_points) live under .entry, not on the row itself. rank is the
// one exception, already top-level on the row.
const entryOf = (e) => e.entry ?? e
const tournamentOf = (e) => e.tournament ?? {}
const progressOf = (e) => {
  const p = e.progress ?? {}
  const picked = p.picked ?? e.picked_count ?? 0
  const total = p.total ?? e.pickable_count ?? 0
  return { picked, total, ratio: total > 0 ? picked / total : null }
}

export default function Dashboard() {
  const user = useAuthStore((s) => s.user)
  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['dashboard'],
    queryFn: api.dashboard,
  })
  // streak flame — quietly optional (analytics endpoint may not be populated yet)
  const { data: analytics } = useQuery({
    queryKey: ['my-analytics'],
    queryFn: api.myAnalytics,
    retry: false,
    staleTime: 120000,
  })
  const { data: notifData } = useQuery({
    queryKey: ['notifications', 'preview'],
    queryFn: () => api.notifications({ per: 3 }),
    retry: false,
  })

  const name = user?.display_name || user?.name || user?.username || 'Champ'
  const streak = analytics?.current_streak ?? analytics?.streak ?? 0

  const entries = data?.entries ?? []
  const pickemEntries = data?.pickem_entries ?? []
  const groups = data?.groups ?? []
  const deadlines = data?.upcoming_deadlines ?? []
  const draftEntries = entries.filter((e) => entryOf(e).status === 'draft')
  const notifs = notifData?.items ?? notifData?.notifications ?? (Array.isArray(notifData) ? notifData : [])

  if (isLoading) return <DashboardSkeleton />

  if (isError) {
    return (
      <div className="py-10">
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title="Dashboard failed to load"
          body={error?.message}
          action={
            <Button onClick={() => refetch()} loading={isRefetching}>
              <RefreshCw size={15} /> Try again
            </Button>
          }
        />
      </div>
    )
  }

  const hasActionItems = draftEntries.length > 0 || deadlines.length > 0

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="space-y-10 py-6">
      {/* ── Greeting ─────────────────────────────────────── */}
      <motion.header variants={rise} className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl uppercase tracking-tight text-ink-100 sm:text-4xl">
            Welcome, <span className="text-gold-400">{name}</span>
          </h1>
          <p className="mt-1.5 text-sm text-ink-500">
            {entries.length ? `You're in ${plural(entries.length, 'bracket')} — keep climbing.` : 'Your corner of the arena.'}
          </p>
        </div>
        {streak > 0 && (
          <div className="flex items-center gap-2 rounded-2xl border border-gold-500/30 bg-gold-500/10 px-4 py-2.5 shadow-glow-sm">
            <Flame size={20} className="text-gold-400" />
            <div>
              <div className="font-mono text-lg font-bold leading-none text-gold-300">{streak}</div>
              <div className="text-[10px] font-bold uppercase tracking-[0.14em] text-gold-500/80">pick streak</div>
            </div>
          </div>
        )}
      </motion.header>

      {/* ── Action needed ────────────────────────────────── */}
      {hasActionItems && (
        <motion.section variants={rise} aria-label="Action needed">
          <SectionHeading sub="Don't leave points on the table.">Action needed</SectionHeading>
          <div className="grid gap-3 md:grid-cols-2">
            {draftEntries.map((e) => {
              const t = tournamentOf(e)
              const prog = progressOf(e)
              return (
                <Card key={`draft-${entryOf(e).id}`} className="flex items-center gap-4 border-gold-500/40 bg-gold-500/[0.05] p-4">
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gold-500/15 text-gold-400">
                    <PencilLine size={18} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-bold text-ink-100">Finish your picks — {t.name}</p>
                    <p className="mt-0.5 text-xs text-ink-400">
                      {prog.total ? `${prog.picked}/${prog.total} picks made` : 'Entry still in draft'}
                      {t.locks_at && (
                        <>
                          {' · locks '}
                          <Countdown to={t.locks_at} />
                        </>
                      )}
                    </p>
                  </div>
                  <Link to={`/tournaments/${t.slug ?? t.id}/predict`}>
                    <Button size="sm">Continue</Button>
                  </Link>
                </Card>
              )
            })}
            {deadlines.map((d, i) => {
              const t = d.tournament ?? d
              return (
                <Card key={`dl-${t.id ?? i}`} className="flex items-center gap-4 border-blood-500/40 bg-blood-500/[0.05] p-4">
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-blood-500/15 text-blood-400">
                    <Clock size={18} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-bold text-ink-100">{t.name} locks soon</p>
                    <p className="mt-0.5 text-xs text-ink-400">
                      Deadline <Countdown to={d.locks_at ?? t.locks_at} />
                    </p>
                  </div>
                  <Link to={`/tournaments/${t.slug ?? t.id}/predict`}>
                    <Button size="sm" variant="danger">
                      Make picks
                    </Button>
                  </Link>
                </Card>
              )
            })}
          </div>
        </motion.section>
      )}

      {/* ── My entries ───────────────────────────────────── */}
      <motion.section variants={rise}>
        <SectionHeading sub="Your bracket challenge entries.">My entries</SectionHeading>
        {entries.length === 0 ? (
          <EmptyState
            icon={<Trophy size={26} />}
            title="No entries yet"
            body="Pick a tournament, predict every match, and take down the competition."
            action={
              <Link to="/tournaments">
                <Button>Browse tournaments</Button>
              </Link>
            }
          />
        ) : (
          <motion.div variants={stagger} className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {entries.map((e) => (
              <EntryCard key={entryOf(e).id} entry={e} />
            ))}
          </motion.div>
        )}
      </motion.section>

      {/* ── Pick'em entries ──────────────────────────────── */}
      <motion.section variants={rise}>
        <SectionHeading sub="Salary-cap showdown entries.">My pick'em</SectionHeading>
        {pickemEntries.length === 0 ? (
          <EmptyState
            icon={<Target size={26} />}
            title="No pick'em entries"
            body="Build a roster under the salary cap — one wrestler per weight."
            action={
              <Link to="/tournaments">
                <Button variant="secondary">Find a tournament</Button>
              </Link>
            }
          />
        ) : (
          <motion.div variants={stagger} className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            {pickemEntries.map((p) => (
              <PickemCard key={entryOf(p).id} entry={p} />
            ))}
          </motion.div>
        )}
      </motion.section>

      {/* ── My groups ────────────────────────────────────── */}
      <motion.section variants={rise}>
        <div className="mb-4 flex items-end justify-between gap-3">
          <SectionHeading className="mb-0" sub="Private leaderboards with your crew.">
            My groups
          </SectionHeading>
          <Link to="/groups" className="inline-flex items-center gap-1 text-sm font-semibold text-gold-400 hover:text-gold-300">
            All groups <ChevronRight size={15} />
          </Link>
        </div>
        {groups.length === 0 ? (
          <EmptyState
            icon={<Users size={26} />}
            title="No groups yet"
            body="Create a group and settle who's the real bracket genius."
            action={
              <Link to="/groups">
                <Button variant="secondary">
                  <Users size={15} /> Go to groups
                </Button>
              </Link>
            }
          />
        ) : (
          <div className="-mx-4 flex snap-x snap-mandatory gap-3 overflow-x-auto px-4 pb-2 no-scrollbar">
            {groups.map((g) => (
              <GroupCard key={g.id} group={g} mine={g.role === 'owner' || g.owner_id === user?.id} compact />
            ))}
          </div>
        )}
      </motion.section>

      {/* ── Notifications preview ────────────────────────── */}
      <motion.section variants={rise}>
        <div className="mb-4 flex items-end justify-between gap-3">
          <SectionHeading className="mb-0" sub="The latest from your brackets.">
            Notifications
          </SectionHeading>
          <Link to="/notifications" className="inline-flex items-center gap-1 text-sm font-semibold text-gold-400 hover:text-gold-300">
            View all <ChevronRight size={15} />
          </Link>
        </div>
        {notifs.length === 0 ? (
          <Card className="flex items-center gap-3 p-4 text-sm text-ink-500">
            <Bell size={16} className="text-ink-600" />
            You're all caught up.
          </Card>
        ) : (
          <Card className="divide-y divide-mat-800">
            {notifs.slice(0, 3).map((n) => (
              <Link
                key={n.id}
                to="/notifications"
                className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-mat-800/60"
              >
                {!n.read_at && <span className="h-2 w-2 shrink-0 rounded-full bg-gold-400" aria-label="Unread" />}
                <span className={cn('min-w-0 flex-1 truncate text-sm', n.read_at ? 'text-ink-400' : 'font-semibold text-ink-100')}>
                  {n.title}
                </span>
                <span className="shrink-0 text-xs text-ink-600">{formatDateTime(n.created_at)}</span>
              </Link>
            ))}
          </Card>
        )}
      </motion.section>
    </motion.div>
  )
}

/* ── Entry rich card ──────────────────────────────────── */
function EntryCard({ entry: row }) {
  const entry = entryOf(row)
  const t = tournamentOf(row)
  const prog = progressOf(row)
  const isDraft = entry.status === 'draft'
  const points = entry.total_points ?? 0
  const possible = entry.possible_points ?? 0
  const ceil = points + possible
  const totalEntries = row.entry_count ?? t.entry_count
  const slug = t.slug ?? t.id

  return (
    <motion.div variants={rise} className="h-full min-w-0">
      <Card hover className="flex h-full min-w-0 flex-col p-5">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <Link to={`/tournaments/${slug}`} className="block truncate font-display text-sm uppercase tracking-wide text-ink-100 hover:text-gold-300">
              {t.name}
            </Link>
            <div className="mt-1.5 flex flex-wrap items-center gap-2">
              {t.year && <span className="font-mono text-xs text-ink-500">{t.year}</span>}
              <StatusPill status={entry.status} />
              {t.status && t.status !== entry.status && <StatusPill status={t.status} />}
            </div>
          </div>
          {prog.ratio != null && <ProgressRing value={prog.ratio} size={44} stroke={4} />}
        </div>

        <div className="mt-4 flex items-end justify-between gap-3">
          <div>
            <div className="text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">Points</div>
            <AnimatedNumber value={points} className="font-mono text-3xl font-bold tracking-tight text-gold-400" />
          </div>
          {row.rank != null && (
            <span className="rounded-lg border border-mat-600 bg-mat-800 px-2.5 py-1.5 font-mono text-sm font-bold text-ink-100">
              #{row.rank}
              {totalEntries ? <span className="text-ink-500"> of {totalEntries}</span> : null}
            </span>
          )}
        </div>

        {/* possible points remaining bar */}
        <div className="mt-4">
          <div className="mb-1 flex justify-between text-[10px] font-bold uppercase tracking-wider text-ink-500">
            <span>Ceiling</span>
            <span className="font-mono normal-case tracking-normal">
              {formatPoints(points)} + <span className="text-pin-400">{formatPoints(possible)} possible</span>
            </span>
          </div>
          <div className="flex h-2 overflow-hidden rounded-full bg-mat-700/70">
            <motion.div
              className="h-full bg-gold-500"
              initial={{ width: 0 }}
              animate={{ width: ceil > 0 ? `${(points / ceil) * 100}%` : 0 }}
              transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
            />
            <motion.div
              className="h-full bg-pin-500/50"
              initial={{ width: 0 }}
              animate={{ width: ceil > 0 ? `${(possible / ceil) * 100}%` : 0 }}
              transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1], delay: 0.1 }}
            />
          </div>
        </div>

        <div className="mt-auto flex gap-2 pt-5">
          {isDraft ? (
            <Link to={`/tournaments/${slug}/predict`} className="flex-1">
              <Button className="w-full" size="sm">
                <PencilLine size={14} /> Continue picks
              </Button>
            </Link>
          ) : (
            <Link to={`/entries/${entry.id}/review`} className="flex-1">
              <Button className="w-full" size="sm">
                <Eye size={14} /> Review
              </Button>
            </Link>
          )}
          <Link to={`/tournaments/${slug}`}>
            <Button variant="secondary" size="sm" aria-label="View bracket">
              <GitBranch size={14} /> Bracket
            </Button>
          </Link>
        </div>
      </Card>
    </motion.div>
  )
}

/* ── Pick'em mini card ────────────────────────────────── */
function PickemCard({ entry: row }) {
  const entry = entryOf(row)
  const t = tournamentOf(row)
  const slug = t.slug ?? t.id
  return (
    <motion.div variants={rise} className="h-full min-w-0">
      <Card hover className="flex h-full min-w-0 flex-col p-4">
        <div className="flex items-center justify-between gap-2">
          <Link to={`/tournaments/${slug}`} className="min-w-0 truncate text-sm font-bold text-ink-100 hover:text-gold-300">
            {t.name}
          </Link>
          <StatusPill status={entry.status} />
        </div>
        <div className="mt-3 flex items-end justify-between">
          <div>
            <div className="text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">Points</div>
            <AnimatedNumber value={entry.total_points ?? 0} className="font-mono text-2xl font-bold text-gold-400" />
          </div>
          {row.rank != null && (
            <Badge color="gold" className="font-mono normal-case">
              #{row.rank}
            </Badge>
          )}
        </div>
        <Link to={`/tournaments/${slug}/pickem`} className="mt-4 block">
          <Button variant="secondary" size="sm" className="w-full">
            {entry.status === 'draft' ? 'Finish roster' : 'View entry'}
          </Button>
        </Link>
      </Card>
    </motion.div>
  )
}

/* ── Skeleton ─────────────────────────────────────────── */
function DashboardSkeleton() {
  return (
    <div className="space-y-10 py-6">
      <div>
        <Skeleton className="h-10 w-72" />
        <Skeleton className="mt-2 h-4 w-48" />
      </div>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {Array.from({ length: 3 }).map((_, i) => (
          <Card key={i} className="p-5">
            <Skeleton className="h-5 w-2/3" />
            <Skeleton className="mt-2 h-4 w-1/3" />
            <Skeleton className="mt-4 h-8 w-24" />
            <Skeleton className="mt-4 h-2 w-full" />
            <Skeleton className="mt-5 h-8 w-full" />
          </Card>
        ))}
      </div>
      <Skeleton className="h-24 w-full" />
      <Skeleton className="h-24 w-full" />
    </div>
  )
}

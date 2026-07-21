import React, { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import {
  AlertTriangle, Check, GitBranch, ListChecks, PencilLine, RefreshCw, Scale, Swords, X,
} from 'lucide-react'
import { api } from '../lib/api'
import { Avatar, Button, Card, EmptyState, Modal, Skeleton, StatusPill } from '../components/ui'
import { cn, formatPoints, pct, plural } from '../lib/utils'
import AnimatedNumber from '../components/profile/AnimatedNumber'
import BracketView from '../components/bracket/BracketView'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

const weightLabel = (w) => (w == null ? '—' : typeof w === 'number' ? `${w} lbs` : String(w))

// entries/{id}/review's champion object is the raw picked wrestler row
// ({id, name, school, seed}) - no nested .wrestler/.champion wrapper.
const champWrestler = (c) => c ?? {}
const champNameOf = (c) => champWrestler(c)?.name ?? null

const EMPTY = {}

export default function EntryReview() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [activeWeight, setActiveWeight] = useState(null)
  const [compareOpen, setCompareOpen] = useState(false)

  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['entry-review', id],
    queryFn: () => api.reviewEntry(id),
    retry: false,
  })

  const review = data ?? EMPTY
  const entry = review.entry ?? {}
  const reviewWeightClasses = review.weight_classes ?? []
  const missingCount = review.missing ?? 0

  // The review payload doesn't nest a tournament object - just tournament_id.
  // Fetch the tournament separately for the header name/year/slug link.
  const tournamentId = entry.tournament_id
  const { data: tData } = useQuery({
    queryKey: ['tournament', tournamentId],
    queryFn: () => api.tournament(tournamentId),
    enabled: !!tournamentId,
  })
  const tournament = tData ?? {}
  const tournamentKey = tournament.slug ?? tournamentId

  // The weight rail/breakdown come straight from the review payload itself -
  // it already has every weight class this entry could pick, no separate
  // tournament fetch needed for that part.
  const weightClasses = useMemo(
    () => reviewWeightClasses.map((w) => ({ id: w.weight_class_id, name: w.name, weight: w.weight })),
    [reviewWeightClasses]
  )

  useEffect(() => {
    if (!activeWeight && weightClasses.length) {
      setActiveWeight(weightClasses[0].id)
    }
  }, [weightClasses, activeWeight])

  const { data: bracketData, isLoading: bracketLoading, isError: bracketError, error: bracketErr, refetch: refetchBracket } = useQuery({
    queryKey: ['entry-bracket', id, activeWeight],
    queryFn: () => api.entryBracketView(id, activeWeight),
    enabled: !!id && !!activeWeight,
  })

  /* one row per weight class, straight from the review payload */
  const weightRows = useMemo(() => {
    const rows = reviewWeightClasses.map((w) => ({
      key: w.weight_class_id,
      weight: w.weight ?? w.name,
      correct: w.correct ?? 0,
      scored: w.scored ?? 0,
      earned: w.points_earned ?? 0,
      possible: 0, // per-weight possible points aren't computed by this endpoint
      champion: w.champion,
      championCorrect: w.champion_correct,
    }))
    rows.sort((a, b) => (parseInt(a.weight, 10) || 999) - (parseInt(b.weight, 10) || 999))
    const maxEarned = Math.max(1, ...rows.map((r) => (r.earned ?? 0) + (r.possible ?? 0)))
    return rows.map((r) => ({ ...r, barMax: maxEarned }))
  }, [reviewWeightClasses])

  if (isLoading) return <ReviewSkeleton />

  if (isError) {
    const denied = error?.status === 403
    return (
      <div className="py-10">
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title={denied ? 'This entry is private' : error?.status === 404 ? 'Entry not found' : 'Review failed to load'}
          body={denied ? 'You can only review your own entries.' : error?.message}
          action={
            denied || error?.status === 404 ? (
              <Link to="/dashboard">
                <Button>Back to dashboard</Button>
              </Link>
            ) : (
              <Button onClick={() => refetch()} loading={isRefetching}>
                <RefreshCw size={15} /> Try again
              </Button>
            )
          }
        />
      </div>
    )
  }

  const points = entry.total_points ?? 0
  const possible = entry.possible_points ?? 0
  const correct = entry.correct_pick_count ?? 0
  const scored = entry.scored_pick_count ?? 0
  const accuracy = scored > 0 ? correct / scored : null
  const isDraftIncomplete = entry.status === 'draft' && missingCount > 0

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="space-y-8 py-6">
      {/* ── Header ─────────────────────────────────────── */}
      <motion.header variants={rise} className="flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0">
          <div className="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-[0.16em] text-gold-400">
            <GitBranch size={12} /> Bracket Challenge
          </div>
          <div className="mt-1 flex flex-wrap items-center gap-3">
            <Link
              to={tournamentKey ? `/tournaments/${tournamentKey}` : '/tournaments'}
              className="font-display text-2xl uppercase tracking-tight text-ink-100 hover:text-gold-300 sm:text-3xl"
            >
              {tournament.name ?? 'Entry review'}
            </Link>
            {tournament.year && <span className="font-mono text-sm text-ink-500">{tournament.year}</span>}
            <StatusPill status={entry.status} />
          </div>
          <div className="mt-3 flex flex-wrap items-end gap-x-8 gap-y-3">
            <div>
              <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Points</div>
              <AnimatedNumber value={points} className="font-mono text-4xl font-bold tracking-tight text-gold-400" />
            </div>
            <div>
              <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Possible remaining</div>
              <div className="font-mono text-2xl font-bold text-pin-400">+{formatPoints(possible)}</div>
            </div>
            <div>
              <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Correct / scored</div>
              <div className="font-mono text-2xl font-bold text-ink-100">
                {correct}
                <span className="text-ink-500">/{scored}</span>
                {accuracy != null && <span className="ml-2 text-base font-bold text-pin-400">{pct(accuracy)}</span>}
              </div>
            </div>
            {entry.rank != null && (
              <div>
                <div className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Rank</div>
                <div className="font-mono text-2xl font-bold text-ink-100">#{entry.rank}</div>
              </div>
            )}
          </div>
        </div>
        <Button variant="secondary" onClick={() => setCompareOpen(true)} disabled={!tournamentId}>
          <Scale size={15} /> Compare
        </Button>
      </motion.header>

      {/* ── Missing picks callout ──────────────────────── */}
      {isDraftIncomplete && (
        <motion.div variants={rise}>
          <Card className="flex flex-wrap items-center gap-4 border-gold-500/50 bg-gold-500/[0.06] p-4">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gold-500/15 text-gold-400">
              <PencilLine size={18} />
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-bold text-ink-100">
                This bracket isn't finished{missingCount ? ` — ${plural(missingCount, 'pick')} missing` : ''}.
              </p>
              <p className="mt-0.5 text-xs text-ink-400">Unsubmitted picks can't score. Finish before the lock.</p>
            </div>
            {tournamentKey && (
              <Link to={`/tournaments/${tournamentKey}/predict`}>
                <Button size="sm">Finish picks</Button>
              </Link>
            )}
          </Card>
        </motion.div>
      )}

      {/* ── Per-weight breakdown ───────────────────────── */}
      {weightRows.length > 0 && (
        <motion.section variants={rise}>
          <h2 className="mb-4 flex items-center gap-2 font-display text-sm uppercase tracking-wide text-ink-100">
            <ListChecks size={16} className="text-gold-400" /> Bracket picks by weight
          </h2>
          <Card className="overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[600px] border-collapse text-sm">
                <thead>
                  <tr className="border-b border-mat-700 text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
                    <th className="w-20 px-4 py-2.5">Weight</th>
                    <th className="px-4 py-2.5">Your champion</th>
                    <th className="px-4 py-2.5 text-right">Correct</th>
                    <th className="w-48 px-4 py-2.5">Points</th>
                  </tr>
                </thead>
                <tbody>
                  {weightRows.map((r) => {
                    const champ = r.champion
                    const cName = champ ? champNameOf(champ) : null
                    const cSeed = champ ? champWrestler(champ)?.seed : null
                    const cCorrect = champ ? r.championCorrect : null
                    const total = (r.earned ?? 0) + (r.possible ?? 0)
                    const barDenom = total > 0 ? total : r.barMax
                    return (
                      <tr key={r.key ?? r.weight} className="border-b border-mat-800 last:border-0">
                        <td className="px-4 py-3 font-mono text-xs font-bold text-gold-400">{weightLabel(r.weight)}</td>
                        <td className="px-4 py-3">
                          {cName ? (
                            <span className="flex items-center gap-2">
                              {cSeed != null && (
                                <span className="rounded bg-mat-700 px-1.5 py-0.5 font-mono text-[10px] font-bold text-gold-400">{cSeed}</span>
                              )}
                              <span className="truncate font-semibold text-ink-100">{cName}</span>
                              {cCorrect === true && (
                                <span className="inline-flex items-center gap-1 rounded bg-pin-500/15 px-1.5 py-0.5 text-[10px] font-bold text-pin-400">
                                  <Check size={10} strokeWidth={3.5} /> HIT
                                </span>
                              )}
                              {cCorrect === false && (
                                <span className="inline-flex items-center gap-1 rounded bg-blood-500/15 px-1.5 py-0.5 text-[10px] font-bold text-blood-400">
                                  <X size={10} strokeWidth={3.5} /> MISS
                                </span>
                              )}
                            </span>
                          ) : (
                            <span className="text-ink-600">—</span>
                          )}
                        </td>
                        <td className="px-4 py-3 text-right font-mono text-sm">
                          <span className="font-bold text-pin-400">{r.correct}</span>
                          <span className="text-ink-500">/{r.scored}</span>
                        </td>
                        <td className="px-4 py-3">
                          <span className="flex items-center gap-2.5">
                            <span className="h-2 flex-1 overflow-hidden rounded-full bg-mat-700/70">
                              <motion.span
                                className="block h-full rounded-full bg-gold-500"
                                initial={{ width: 0 }}
                                animate={{ width: `${Math.min(100, ((r.earned ?? 0) / barDenom) * 100)}%` }}
                                transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
                              />
                            </span>
                            <span className="w-16 shrink-0 text-right font-mono text-xs font-bold text-ink-100">
                              {formatPoints(r.earned)}
                              {total > 0 && <span className="text-ink-500">/{formatPoints(total)}</span>}
                            </span>
                          </span>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </Card>
        </motion.section>
      )}

      {/* ── Bracket ────────────────────────────────────── */}
      <motion.section variants={rise}>
        <h2 className="mb-4 flex items-center gap-2 font-display text-sm uppercase tracking-wide text-ink-100">
          <GitBranch size={16} className="text-gold-400" /> Your bracket
        </h2>

        {/* weight rail */}
        {weightClasses.length > 0 && (
          <div className="-mx-1 mb-4 flex gap-2 overflow-x-auto px-1 pb-1 no-scrollbar" role="tablist" aria-label="Weight classes">
            {weightClasses.map((w) => {
              const row = weightRows.find((r) => r.key === w.id)
              const active = w.id === activeWeight
              return (
                <button
                  key={w.id}
                  role="tab"
                  aria-selected={active}
                  onClick={() => setActiveWeight(w.id)}
                  className={cn(
                    'flex shrink-0 items-center gap-2 rounded-full border px-3.5 py-2 text-xs font-bold transition-all',
                    active
                      ? 'border-gold-500 bg-gold-500/15 text-gold-400 shadow-glow-sm'
                      : 'border-mat-600 bg-mat-850 text-ink-400 hover:border-mat-500 hover:text-ink-100'
                  )}
                >
                  {w.name ?? weightLabel(w.weight)}
                  {row && (
                    <span className={cn('font-mono text-[10px]', active ? 'text-gold-300' : 'text-ink-600')}>
                      {formatPoints(row.earned)}pt
                    </span>
                  )}
                </button>
              )
            })}
          </div>
        )}

        {bracketLoading ? (
          <Skeleton className="h-[60vh] w-full" />
        ) : bracketError ? (
          <Card className="flex flex-wrap items-center justify-between gap-3 p-5">
            <span className="text-sm text-ink-400">{bracketErr?.message || 'Bracket unavailable for this weight.'}</span>
            <Button variant="secondary" size="sm" onClick={() => refetchBracket()}>
              <RefreshCw size={14} /> Retry
            </Button>
          </Card>
        ) : bracketData ? (
          <BracketView data={bracketData} mode="results" />
        ) : (
          <Card className="p-8 text-center text-sm text-ink-500">Pick a weight class above to see your bracket.</Card>
        )}
      </motion.section>

      {/* ── Compare modal ──────────────────────────────── */}
      <ComparePicker
        open={compareOpen}
        onClose={() => setCompareOpen(false)}
        tournamentId={tournamentId}
        myEntryId={entry.id ?? id}
        onPick={(otherId) => navigate(`/compare/${entry.id ?? id}/${otherId}`)}
      />
    </motion.div>
  )
}

/* ── Compare picker — choose an opponent from the leaderboard ── */
function ComparePicker({ open, onClose, tournamentId, myEntryId, onPick }) {
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ['leaderboard', tournamentId, 'compare-picker'],
    queryFn: () => api.leaderboard(tournamentId, { per: 25 }),
    enabled: open && !!tournamentId,
  })
  const rows = (data?.entries ?? data?.items ?? (Array.isArray(data) ? data : [])).filter(
    (r) => String(r.entry_id ?? r.id) !== String(myEntryId)
  )
  return (
    <Modal open={open} onClose={onClose} title="Compare against…">
      {isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-12 w-full" />
          ))}
        </div>
      ) : isError ? (
        <div className="py-6 text-center">
          <p className="text-sm text-ink-400">Leaderboard unavailable.</p>
          <Button variant="secondary" size="sm" className="mt-3" onClick={() => refetch()}>
            <RefreshCw size={14} /> Retry
          </Button>
        </div>
      ) : rows.length === 0 ? (
        <p className="py-6 text-center text-sm text-ink-500">No other entries to compare against yet.</p>
      ) : (
        <ul className="max-h-[55vh] space-y-1.5 overflow-y-auto pr-1">
          {rows.map((r, i) => {
            const u = r.user ?? r
            return (
              <li key={r.entry_id ?? r.id ?? i}>
                <button
                  onClick={() => onPick(r.entry_id ?? r.id)}
                  className="flex w-full items-center gap-3 rounded-xl border border-mat-700 bg-mat-800/60 px-3 py-2.5 text-left transition-colors hover:border-gold-500/40 hover:bg-mat-800"
                >
                  <span className={cn('w-8 text-center font-mono text-sm font-bold', (r.rank ?? i + 1) <= 3 ? 'text-gold-400' : 'text-ink-400')}>
                    {r.rank ?? i + 1}
                  </span>
                  <Avatar user={u} size="sm" />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-semibold text-ink-100">{u.display_name || u.name || u.username}</span>
                    <span className="block font-mono text-xs text-ink-500">{formatPoints(r.total_points)} pts</span>
                  </span>
                  <Swords size={15} className="shrink-0 text-gold-500/70" />
                </button>
              </li>
            )
          })}
        </ul>
      )}
    </Modal>
  )
}

/* ── Skeleton ─────────────────────────────────────────── */
function ReviewSkeleton() {
  return (
    <div className="space-y-8 py-6">
      <div>
        <Skeleton className="h-9 w-80" />
        <div className="mt-4 flex gap-8">
          <Skeleton className="h-14 w-24" />
          <Skeleton className="h-14 w-24" />
          <Skeleton className="h-14 w-32" />
        </div>
      </div>
      <Skeleton className="h-56 w-full" />
      <div>
        <Skeleton className="mb-4 h-6 w-40" />
        <div className="mb-4 flex gap-2">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-9 w-20 rounded-full" />
          ))}
        </div>
        <Skeleton className="h-[60vh] w-full" />
      </div>
    </div>
  )
}

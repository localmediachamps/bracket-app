import React, { useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, RefreshCw, Scale, Swords, Trophy } from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore } from '../lib/store'
import { Avatar, Badge, Button, Card, EmptyState, Skeleton, Tabs } from '../components/ui'
import { cn, formatPoints, pct } from '../lib/utils'
import AnimatedNumber from '../components/profile/AnimatedNumber'
import Donut from '../components/profile/Donut'
import DualBar from '../components/profile/DualBar'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

const entryUser = (e) => e?.user ?? e ?? {}
const entryName = (e) => {
  const u = entryUser(e)
  return u.display_name || u.name || u.username || 'Unknown'
}
const pickOf = (p) => p?.wrestler ?? p ?? {}
const champName = (v) => (typeof v === 'string' ? v : v?.name ?? v?.wrestler?.name ?? null)
const champSeed = (v) => (typeof v === 'object' && v ? v.seed ?? v.wrestler?.seed ?? null : null)
const accOf = (e, correct) => {
  const scored = e?.scored_pick_count ?? 0
  return scored > 0 ? (correct ?? e?.correct_pick_count ?? 0) / scored : 0
}

export default function Compare() {
  const { aId, bId } = useParams()
  const me = useAuthStore((s) => s.user)
  const [tab, setTab] = useState('diff')

  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['compare', aId, bId],
    queryFn: () => api.compareEntries(aId, bId),
    retry: false,
  })

  /* orient: "you" on the left whenever one side is the requester */
  const oriented = useMemo(() => {
    if (!data) return null
    let you = data.a ?? {}
    let them = data.b ?? {}
    let youCorrect = data.a_correct ?? you.correct_pick_count ?? 0
    let themCorrect = data.b_correct ?? them.correct_pick_count ?? 0
    const bIsMe = me?.id != null && entryUser(data.b).id === me.id
    const aIsMe = me?.id != null && entryUser(data.a).id === me.id
    if (bIsMe && !aIsMe) {
      you = data.b
      them = data.a
      youCorrect = data.b_correct ?? you.correct_pick_count ?? 0
      themCorrect = data.a_correct ?? them.correct_pick_count ?? 0
    }
    return {
      you, them, youCorrect, themCorrect,
      youIsMe: aIsMe || bIsMe,
      swapped: bIsMe && !aIsMe,
      youChamps: (bIsMe && !aIsMe ? data.champions?.b : data.champions?.a) ?? {},
      themChamps: (bIsMe && !aIsMe ? data.champions?.a : data.champions?.b) ?? {},
      common: data.common_picks ?? 0,
      differing: data.differing_picks ?? 0,
      decisive: data.decisive_matches ?? [],
    }
  }, [data, me?.id])

  const championRows = useMemo(() => {
    if (!oriented) return []
    const keys = new Set([...Object.keys(oriented.youChamps), ...Object.keys(oriented.themChamps)])
    const rows = [...keys].map((w) => ({
      weight: w,
      you: oriented.youChamps[w],
      them: oriented.themChamps[w],
      differ: (champName(oriented.youChamps[w]) ?? '') !== (champName(oriented.themChamps[w]) ?? ''),
    }))
    rows.sort((x, y) => (parseInt(x.weight, 10) || 999) - (parseInt(y.weight, 10) || 999) || String(x.weight).localeCompare(String(y.weight)))
    return rows
  }, [oriented])

  if (isLoading) {
    return (
      <div className="space-y-6 py-6">
        <div className="grid grid-cols-[1fr_auto_1fr] items-stretch gap-3">
          <Skeleton className="h-36" />
          <Skeleton className="h-10 w-16 self-center rounded-full" />
          <Skeleton className="h-36" />
        </div>
        <Skeleton className="h-40 w-full" />
        <Skeleton className="h-56 w-full" />
      </div>
    )
  }

  if (isError) {
    const denied = error?.status === 403
    return (
      <div className="py-10">
        <EmptyState
          icon={denied ? <Scale size={26} /> : <AlertTriangle size={26} />}
          title={denied ? "You can't compare these entries" : error?.status === 404 ? 'Entry not found' : 'Comparison failed to load'}
          body={denied ? 'Head-to-head works between your own entries and entries in groups you share.' : error?.message}
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

  const { you, them, youCorrect, themCorrect, youIsMe, swapped, youChamps, themChamps, common, differing, decisive } = oriented
  const youPts = you.total_points ?? 0
  const themPts = them.total_points ?? 0
  const lead = youPts - themPts
  const youName = youIsMe ? 'You' : entryName(you)
  const themName = entryName(them)
  const leaderName = lead > 0 ? youName : themName

  const statRows = [
    { label: 'Points', a: youPts, b: themPts, format: formatPoints },
    { label: 'Possible', a: you.possible_points ?? 0, b: them.possible_points ?? 0, format: formatPoints },
    { label: 'Correct', a: youCorrect, b: themCorrect, format: (v) => v },
    { label: 'Accuracy', a: accOf(you, youCorrect), b: accOf(them, themCorrect), format: (v) => pct(v), max: 1 },
    {
      label: 'Champions',
      a: you.champions_correct ?? Object.keys(youChamps).length,
      b: them.champions_correct ?? Object.keys(themChamps).length,
      format: (v) => v,
    },
  ]

  const filteredChamps = tab === 'diff' ? championRows.filter((r) => r.differ) : championRows

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="space-y-8 py-6">
      {/* ── Split header ───────────────────────────────── */}
      <motion.div variants={rise} className="grid grid-cols-[1fr_auto_1fr] items-stretch gap-2 sm:gap-4">
        <IdentityCard entry={you} name={youName} isYou={youIsMe} leading={lead > 0} side="you" />
        <div className="flex flex-col items-center justify-center gap-2 px-1">
          <span className="flex h-10 w-10 items-center justify-center rounded-full border border-mat-600 bg-mat-850 font-display text-[10px] uppercase text-ink-400 sm:h-12 sm:w-12 sm:text-xs">
            VS
          </span>
          {lead !== 0 ? (
            <Badge color="gold" className="whitespace-nowrap normal-case">
              {leaderName === 'You' ? 'You lead' : `${leaderName} leads`} by {formatPoints(Math.abs(lead))}
            </Badge>
          ) : (
            <Badge color="ink" className="whitespace-nowrap normal-case">Dead even</Badge>
          )}
        </div>
        <IdentityCard entry={them} name={themName} leading={lead < 0} side="them" />
      </motion.div>

      {/* ── Stat comparison ────────────────────────────── */}
      <motion.section variants={rise}>
        <Card className="p-5">
          <h2 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Stat comparison</h2>
          <div className="space-y-4">
            {statRows.map((r) => (
              <DualBar key={r.label} label={r.label} a={r.a} b={r.b} max={r.max} format={r.format} />
            ))}
          </div>
        </Card>
      </motion.section>

      {/* ── Decisive matches + donut ───────────────────── */}
      <motion.section variants={rise} className="grid items-start gap-4 lg:grid-cols-[1fr_300px]">
        <Card className="p-5">
          <div className="mb-1 flex items-center gap-2">
            <Swords size={16} className="text-gold-400" />
            <h2 className="font-display text-sm uppercase tracking-wide text-ink-100">Decisive matches</h2>
          </div>
          {decisive.length === 0 ? (
            <p className="py-8 text-center text-sm text-ink-500">
              No pending disagreements — every match that could separate you is already settled.
            </p>
          ) : (
            <>
              <p className="mb-4 text-xs text-ink-500">
                These <span className="font-bold text-gold-400">{decisive.length}</span> pending match{decisive.length === 1 ? '' : 'es'} will separate you.
              </p>
              <ul className="space-y-2.5">
                {decisive.map((m, i) => {
                  // a_pick/b_pick follow the API's a/b orientation; map onto you/them
                  const youPick = pickOf(swapped ? m.b_pick : m.a_pick)
                  const themPick = pickOf(swapped ? m.a_pick : m.b_pick)
                  return (
                    <li key={m.id ?? m.match_id ?? i} className="rounded-xl border border-mat-700 bg-mat-900/60 p-3">
                      <div className="mb-2 flex items-center gap-2 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
                        {m.weight || m.weight_class_name ? <span className="text-gold-500">{m.weight ?? m.weight_class_name}</span> : null}
                        <span>{m.match_label ?? m.round_label ?? 'Match'}{m.match_number != null ? ` #${m.match_number}` : ''}</span>
                      </div>
                      <div className="grid grid-cols-2 gap-2">
                        <PickCell pick={youPick} label={youName} tone="gold" />
                        <PickCell pick={themPick} label={themName} tone="blood" />
                      </div>
                    </li>
                  )
                })}
              </ul>
            </>
          )}
        </Card>

        <Card className="flex flex-col items-center p-5">
          <h2 className="mb-4 self-start font-display text-sm uppercase tracking-wide text-ink-100">Pick overlap</h2>
          <Donut
            size={170}
            stroke={20}
            segments={[
              { value: common, color: 'var(--color-gold-500)', label: 'Shared' },
              { value: differing, color: 'var(--color-blood-500)', label: 'Differing' },
            ]}
            center={
              <span className="font-mono text-3xl font-bold text-ink-100">
                <AnimatedNumber value={common + differing} />
              </span>
            }
            sub="picks compared"
          />
          {common + differing > 0 && (
            <p className="mt-3 text-center text-xs text-ink-500">
              You agree on <span className="font-bold text-gold-400">{pct(common / (common + differing))}</span> of scored-match picks.
            </p>
          )}
        </Card>
      </motion.section>

      {/* ── Champions by weight ────────────────────────── */}
      <motion.section variants={rise}>
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <h2 className="flex items-center gap-2 font-display text-sm uppercase tracking-wide text-ink-100">
            <Trophy size={16} className="text-gold-400" /> Champions by weight
          </h2>
          <Tabs
            tabs={[
              { key: 'diff', label: 'Only differences', count: championRows.filter((r) => r.differ).length },
              { key: 'all', label: 'All picks', count: championRows.length },
            ]}
            active={tab}
            onChange={setTab}
            className="border-b-0"
          />
        </div>
        <Card className="overflow-hidden">
          {filteredChamps.length === 0 ? (
            <p className="py-10 text-center text-sm text-ink-500">
              {tab === 'diff' ? 'Same champions across the board — spooky.' : 'No champion picks yet.'}
            </p>
          ) : (
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="border-b border-mat-700 text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
                  <th className="w-20 px-4 py-2.5">Weight</th>
                  <th className="px-4 py-2.5">{youName}</th>
                  <th className="px-4 py-2.5">{themName}</th>
                </tr>
              </thead>
              <tbody>
                {filteredChamps.map((r) => (
                  <tr key={r.weight} className="border-b border-mat-800 last:border-0">
                    <td className="px-4 py-3 font-mono text-xs font-bold text-gold-400">{r.weight}</td>
                    <td className={cn('px-4 py-3', r.differ && 'bg-gold-500/[0.07]')}>
                      <ChampionCell value={r.you} highlight={r.differ} tone="gold" />
                    </td>
                    <td className={cn('px-4 py-3', r.differ && 'bg-blood-500/[0.07]')}>
                      <ChampionCell value={r.them} highlight={r.differ} tone="blood" />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Card>
      </motion.section>
    </motion.div>
  )
}

/* ── Identity card ────────────────────────────────────── */
function IdentityCard({ entry, name, isYou, leading, side }) {
  const u = entryUser(entry)
  return (
    <Card
      className={cn(
        'flex h-full flex-col items-center gap-2 p-5 text-center',
        leading && 'border-gold-500/50 shadow-glow',
        side === 'them' && !leading && 'border-blood-500/25'
      )}
    >
      <Avatar user={u} size="lg" ring={leading} />
      <div className="min-w-0">
        <div className="flex items-center justify-center gap-1.5">
          <span className="truncate text-sm font-bold text-ink-100">{name}</span>
          {isYou && <Badge color="gold">You</Badge>}
        </div>
        {u.username && !isYou && <div className="text-xs text-ink-500">@{u.username}</div>}
        {entry.rank != null && <div className="mt-0.5 font-mono text-xs text-ink-400">Rank #{entry.rank}</div>}
      </div>
      <AnimatedNumber
        value={entry.total_points ?? 0}
        className={cn(
          'font-mono font-bold tracking-tight',
          leading ? 'text-4xl text-gold-300 [text-shadow:0_0_24px_rgb(232_174_46/0.45)]' : 'text-2xl text-ink-200'
        )}
      />
      <span className="text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">points</span>
    </Card>
  )
}

/* ── Pick cells ───────────────────────────────────────── */
function PickCell({ pick, label, tone }) {
  const gold = tone === 'gold'
  return (
    <div className={cn('rounded-lg border p-2', gold ? 'border-gold-500/30 bg-gold-500/[0.06]' : 'border-blood-500/30 bg-blood-500/[0.06]')}>
      <div className={cn('text-[9px] font-bold uppercase tracking-[0.14em]', gold ? 'text-gold-500' : 'text-blood-400')}>{label}</div>
      <div className="mt-1 flex items-center gap-1.5">
        {pick.seed != null && (
          <span className="rounded bg-mat-700 px-1 py-px font-mono text-[10px] font-bold text-gold-400">{pick.seed}</span>
        )}
        <span className="truncate text-xs font-semibold text-ink-100">{pick.name ?? '—'}</span>
      </div>
      {pick.school && <div className="mt-0.5 truncate text-[10px] text-ink-500">{pick.school}</div>}
    </div>
  )
}

function ChampionCell({ value, highlight, tone }) {
  const name = champName(value)
  const seed = champSeed(value)
  if (!name) return <span className="text-ink-600">—</span>
  return (
    <span className="flex items-center gap-2">
      {seed != null && <span className="rounded bg-mat-700 px-1.5 py-0.5 font-mono text-[10px] font-bold text-gold-400">{seed}</span>}
      <span className={cn('truncate font-semibold', highlight ? (tone === 'gold' ? 'text-gold-300' : 'text-blood-300') : 'text-ink-200')}>
        {name}
      </span>
    </span>
  )
}

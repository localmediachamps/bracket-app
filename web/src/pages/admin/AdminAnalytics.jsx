import React from 'react'
import { useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { BarChart3, Crown, TrendingUp, Users } from 'lucide-react'
import { api } from '../../lib/api'
import { Card, EmptyState, Skeleton, Stat } from '../../components/ui'
import { cn, formatPoints, pct } from '../../lib/utils'
import { ErrorState, PageHeader, ProgressBar } from '../../components/admin/AdminCommon'

export default function AdminAnalytics() {
  const { id } = useParams()
  const aQ = useQuery({ queryKey: ['admin', 'analytics', id], queryFn: () => api.adminAnalytics(id) })

  if (aQ.isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-9 w-72" />
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
          {[...Array(5)].map((_, i) => <Skeleton key={i} className="h-[92px]" />)}
        </div>
        <Skeleton className="h-56" />
        <Skeleton className="h-56" />
      </div>
    )
  }
  if (aQ.isError) return <ErrorState error={aQ.error} onRetry={() => aQ.refetch()} title="Couldn't load analytics" />

  const a = aQ.data ?? {}
  const totals = {
    entries: a.total_entries ?? a.entries ?? a.totals?.entries ?? 0,
    submitted: a.submitted_entries ?? a.submitted ?? a.totals?.submitted ?? 0,
    drafts: a.draft_entries ?? a.drafts ?? a.totals?.drafts ?? 0,
    groups: a.group_count ?? a.groups ?? a.totals?.groups ?? 0,
    avg: a.avg_score ?? a.average_score ?? a.totals?.avg_score ?? 0,
  }
  const funnelRaw = a.funnel ?? a.completion_funnel ?? null
  const funnel = normalizeFunnel(funnelRaw, totals)
  const champions = a.most_picked_champions ?? a.champions ?? []
  const histogram = normalizeHistogram(a.score_histogram ?? a.histogram ?? [])
  const hardest = a.hardest_matches ?? a.least_correct_matches ?? a.least_correct ?? []
  const easiest = a.easiest_matches ?? a.most_correct_matches ?? a.most_correct ?? []
  const overTime = (a.entries_over_time ?? a.entries_by_day ?? []).map((p) => ({
    date: p.date ?? p.day,
    count: Number(p.count ?? p.entries ?? 0),
  }))

  return (
    <div>
      <PageHeader title="Analytics" sub="Entry health, pick trends and score distribution." />

      {/* stat cards */}
      <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-5">
        {[
          { label: 'Total entries', value: totals.entries, icon: <Users size={16} /> },
          { label: 'Submitted', value: totals.submitted, icon: <TrendingUp size={16} /> },
          { label: 'Drafts', value: totals.drafts, icon: <Users size={16} /> },
          { label: 'Groups', value: totals.groups, icon: <Users size={16} /> },
          { label: 'Avg score', value: formatPoints(totals.avg), icon: <BarChart3 size={16} /> },
        ].map((s, i) => (
          <motion.div key={s.label} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.04 }}>
            <Stat label={s.label} value={s.value} icon={s.icon} />
          </motion.div>
        ))}
      </div>

      <div className="grid gap-5 lg:grid-cols-2">
        {/* completion funnel */}
        <Card className="p-5">
          <h2 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Completion funnel</h2>
          {funnel.every((f) => !f.count) ? (
            <p className="py-8 text-center text-sm text-ink-500">No entry activity yet.</p>
          ) : (
            <div className="space-y-3">
              {funnel.map((f, i) => {
                const max = funnel[0]?.count || 1
                const ratio = f.count / max
                return (
                  <div key={f.label}>
                    <div className="mb-1 flex items-baseline justify-between text-xs">
                      <span className="font-semibold text-ink-300">{f.label}</span>
                      <span className="font-mono text-ink-500">
                        {f.count}
                        {i > 0 && funnel[i - 1].count > 0 && (
                          <span className="ml-2 text-gold-400">{pct(f.count / funnel[i - 1].count)}</span>
                        )}
                      </span>
                    </div>
                    <div className="h-6 overflow-hidden rounded-md bg-mat-800">
                      <motion.div
                        initial={{ width: 0 }}
                        animate={{ width: `${Math.max(ratio * 100, f.count ? 3 : 0)}%` }}
                        transition={{ duration: 0.6, delay: i * 0.08, ease: [0.22, 1, 0.36, 1] }}
                        className={cn('flex h-full items-center justify-end rounded-md pr-2', i === funnel.length - 1 ? 'bg-pin-500/80' : 'bg-gold-500/80')}
                      >
                        <span className="font-mono text-[10px] font-bold text-mat-950">{pct(ratio)}</span>
                      </motion.div>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </Card>

        {/* entries over time */}
        <Card className="p-5">
          <h2 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Entries over time</h2>
          {overTime.length < 2 ? (
            <p className="py-8 text-center text-sm text-ink-500">Not enough data yet — entries will chart here by day.</p>
          ) : (
            <AreaChart points={overTime} />
          )}
        </Card>
      </div>

      {/* most-picked champions */}
      <Card className="mt-5 p-5">
        <h2 className="mb-4 flex items-center gap-2 font-display text-sm uppercase tracking-wide text-ink-100">
          <Crown size={15} className="text-gold-500" /> Most-picked champion per weight
        </h2>
        {champions.length === 0 ? (
          <EmptyState icon={<Crown size={22} />} title="No picks yet" body="Champion pick distribution appears once players start picking." />
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
            {champions.map((c, i) => {
              const share = c.pct ?? c.percentage ?? (c.count && totals.entries ? c.count / totals.entries : 0)
              const name = c.name ?? c.wrestler?.name ?? c.wrestler_name ?? '—'
              const school = c.school ?? c.wrestler?.school ?? ''
              return (
                <motion.div
                  key={c.weight_class_id ?? c.weight ?? i}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.04 }}
                  className="rounded-xl border border-mat-700 bg-mat-800/60 p-3.5"
                >
                  <div className="flex items-baseline justify-between">
                    <span className="font-mono text-xs font-bold text-gold-400">{c.weight ?? c.weight_class ?? ''} lbs</span>
                    <span className="font-mono text-xs font-bold text-ink-300">{typeof share === 'number' ? pct(share > 1 ? share / 100 : share) : '—'}</span>
                  </div>
                  <p className="mt-1.5 truncate text-sm font-semibold text-ink-100" title={name}>{name}</p>
                  <p className="truncate text-[11px] text-ink-500">{school}{c.count != null ? ` · ${c.count} picks` : ''}</p>
                  <ProgressBar className="mt-2" value={typeof share === 'number' ? (share > 1 ? share / 100 : share) : 0} />
                </motion.div>
              )
            })}
          </div>
        )}
      </Card>

      {/* score histogram */}
      <Card className="mt-5 p-5">
        <h2 className="mb-4 font-display text-sm uppercase tracking-wide text-ink-100">Score histogram</h2>
        {histogram.every((b) => !b.count) ? (
          <p className="py-8 text-center text-sm text-ink-500">No scores yet — distribution appears once entries are scored.</p>
        ) : (
          <Histogram bars={histogram} />
        )}
      </Card>

      {/* hardest / easiest */}
      <div className="mt-5 grid gap-5 lg:grid-cols-2">
        <MatchPredictability title="Hardest matches" sub="Least correctly predicted" rows={hardest} tone="blood" />
        <MatchPredictability title="Easiest matches" sub="Most correctly predicted" rows={easiest} tone="pin" />
      </div>
    </div>
  )
}

/* ── shape normalizers (tolerate contract variants) ─── */
function normalizeFunnel(raw, totals) {
  const steps = ['Viewed', 'Created entry', '50%+ picked', 'Submitted']
  if (Array.isArray(raw) && raw.length && typeof raw[0] === 'object') {
    return steps.map((label, i) => ({ label, count: Number(raw[i]?.count ?? raw[i]?.value ?? 0) }))
  }
  const obj = raw ?? {}
  return [
    { label: steps[0], count: Number(obj.viewed ?? obj.views ?? totals.entries ?? 0) },
    { label: steps[1], count: Number(obj.created ?? obj.created_entry ?? totals.entries ?? 0) },
    { label: steps[2], count: Number(obj.half ?? obj.half_complete ?? obj.fifty_percent ?? 0) },
    { label: steps[3], count: Number(obj.submitted ?? totals.submitted ?? 0) },
  ]
}

function normalizeHistogram(raw) {
  if (!Array.isArray(raw) || raw.length === 0) return []
  if (typeof raw[0] === 'number') return raw.map((count, i) => ({ label: `B${i + 1}`, count }))
  return raw.map((b, i) => ({
    label: b.label ?? b.bucket ?? (b.min != null && b.max != null ? `${b.min}–${b.max}` : `B${i + 1}`),
    count: Number(b.count ?? b.value ?? 0),
  }))
}

/* ── hand-rolled SVG charts ─────────────────────────── */
function AreaChart({ points }) {
  const W = 560
  const H = 140
  const PAD = 8
  const max = Math.max(...points.map((p) => p.count), 1)
  const stepX = (W - PAD * 2) / (points.length - 1)
  const coords = points.map((p, i) => [PAD + i * stepX, H - PAD - (p.count / max) * (H - PAD * 2)])
  const line = coords.map((c, i) => `${i === 0 ? 'M' : 'L'}${c[0].toFixed(1)},${c[1].toFixed(1)}`).join(' ')
  const area = `${line} L${coords[coords.length - 1][0].toFixed(1)},${H - PAD} L${coords[0][0].toFixed(1)},${H - PAD} Z`
  return (
    <div>
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full" role="img" aria-label="Entries over time area chart">
        <defs>
          <linearGradient id="areaGold" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--color-gold-500)" stopOpacity="0.35" />
            <stop offset="100%" stopColor="var(--color-gold-500)" stopOpacity="0.02" />
          </linearGradient>
        </defs>
        {[0.25, 0.5, 0.75].map((f) => (
          <line key={f} x1={PAD} x2={W - PAD} y1={H * f} y2={H * f} stroke="var(--color-mat-700)" strokeWidth="1" strokeDasharray="3 4" />
        ))}
        <motion.path initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.5 }} d={area} fill="url(#areaGold)" />
        <motion.path
          initial={{ pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ duration: 0.9, ease: 'easeOut' }}
          d={line}
          fill="none"
          stroke="var(--color-gold-500)"
          strokeWidth="2"
          strokeLinecap="round"
        />
        {coords.map((c, i) => (
          <circle key={i} cx={c[0]} cy={c[1]} r="2.5" fill="var(--color-gold-400)" />
        ))}
      </svg>
      <div className="mt-1 flex justify-between text-[10px] text-ink-600">
        <span>{points[0]?.date}</span>
        <span className="font-mono text-gold-400">peak {max}/day</span>
        <span>{points[points.length - 1]?.date}</span>
      </div>
    </div>
  )
}

function Histogram({ bars }) {
  const W = 560
  const H = 150
  const PAD_B = 22
  const max = Math.max(...bars.map((b) => b.count), 1)
  const bw = W / bars.length
  return (
    <div>
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full" role="img" aria-label="Score distribution histogram">
        {bars.map((b, i) => {
          const h = (b.count / max) * (H - PAD_B - 8)
          return (
            <g key={i}>
              <motion.rect
                initial={{ height: 0, y: H - PAD_B }}
                animate={{ height: Math.max(h, b.count ? 2 : 0), y: H - PAD_B - Math.max(h, b.count ? 2 : 0) }}
                transition={{ duration: 0.5, delay: i * 0.04, ease: [0.22, 1, 0.36, 1] }}
                x={i * bw + 3}
                width={bw - 6}
                rx={3}
                fill="var(--color-gold-500)"
                opacity={0.55 + (0.45 * b.count) / max}
              />
              {b.count > 0 && (
                <text x={i * bw + bw / 2} y={H - PAD_B - h - 4} textAnchor="middle" fontSize="9" fill="var(--color-ink-400)" fontFamily="JetBrains Mono, monospace">
                  {b.count}
                </text>
              )}
              <text x={i * bw + bw / 2} y={H - 8} textAnchor="middle" fontSize="8" fill="var(--color-ink-600)" fontFamily="JetBrains Mono, monospace">
                {b.label}
              </text>
            </g>
          )
        })}
        <line x1={0} x2={W} y1={H - PAD_B} y2={H - PAD_B} stroke="var(--color-mat-600)" strokeWidth="1" />
      </svg>
    </div>
  )
}

function MatchPredictability({ title, sub, rows, tone }) {
  const list = (rows ?? []).slice(0, 10)
  return (
    <Card className="p-5">
      <h2 className="font-display text-sm uppercase tracking-wide text-ink-100">{title}</h2>
      <p className="mb-4 text-xs text-ink-500">{sub}</p>
      {list.length === 0 ? (
        <p className="py-6 text-center text-sm text-ink-500">No scored matches yet.</p>
      ) : (
        <table className="w-full text-sm">
          <tbody>
            {list.map((m, i) => {
              const share = m.correct_pct ?? m.pct_correct ?? m.correct_percentage ?? 0
              const ratio = share > 1 ? share / 100 : share
              const label = m.label ?? m.match_label ?? `${m.weight ? `${m.weight} lbs · ` : ''}${m.round_label ?? ''} #${m.match_number ?? m.match_id ?? i + 1}`
              return (
                <tr key={m.match_id ?? m.id ?? i} className="border-b border-mat-700/50 last:border-0">
                  <td className="py-2 pr-3">
                    <span className="block truncate text-xs font-semibold text-ink-200">{label}</span>
                  </td>
                  <td className="w-28 py-2">
                    <ProgressBar value={ratio} tone={tone} />
                  </td>
                  <td className={cn('w-14 py-2 text-right font-mono text-xs font-bold', tone === 'blood' ? 'text-blood-400' : 'text-pin-400')}>
                    {pct(ratio)}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      )}
    </Card>
  )
}

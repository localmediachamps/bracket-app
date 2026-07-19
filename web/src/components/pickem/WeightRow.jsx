import React from 'react'
import { motion } from 'framer-motion'
import { ArrowLeftRight, X } from 'lucide-react'
import { Skeleton } from '../ui'

/**
 * WeightRow — one weight class row in the pick'em editor: the selected wrestler
 * (seed, name, school, cost chip) with swap/remove actions, or a dashed
 * "Choose wrestler" button. In read-only mode shows earned points + breakdown.
 */
export default function WeightRow({ wc, wrestler, cost, loading, readOnly, pointsEarned, breakdown, onOpen, onRemove, index = 0 }) {
  const label = wc.weight ?? wc.name
  const breakdownChips = breakdown
    ? [
        ['Place', breakdown.placement],
        ['Wins', breakdown.wins],
        ['Bonus', breakdown.bonus],
      ].filter(([, v]) => v != null && v !== 0)
    : []

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: Math.min(index * 0.04, 0.3), duration: 0.25 }}
      className="rounded-xl border border-mat-700 bg-mat-850 p-3 shadow-card"
    >
      <div className="flex items-center gap-3">
        <span className="flex h-11 w-12 shrink-0 items-center justify-center rounded-lg bg-mat-800 font-mono text-sm font-bold text-gold-400">
          {label}
        </span>
        {loading ? (
          <div className="flex flex-1 items-center gap-3">
            <Skeleton className="h-6 w-6" />
            <div className="flex-1 space-y-1.5">
              <Skeleton className="h-3.5 w-2/5" />
              <Skeleton className="h-3 w-1/4" />
            </div>
          </div>
        ) : wrestler ? (
          <>
            <span className="flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded bg-mat-700 font-mono text-[10px] font-bold text-gold-400">
              {wrestler.seed ?? '–'}
            </span>
            <span className="min-w-0 flex-1 leading-tight">
              <span className="block truncate text-sm font-semibold text-ink-100">{wrestler.name}</span>
              <span className="block truncate text-[11px] text-ink-500">
                {wrestler.school}
                {wrestler.record ? ` · ${wrestler.record}` : ''}
              </span>
            </span>
            <span
              className="shrink-0 rounded-lg border border-gold-500/30 bg-gold-500/12 px-2 py-1 font-mono text-xs font-bold text-gold-300"
              title="Salary cost"
            >
              {cost}
            </span>
            {readOnly && pointsEarned != null && (
              <span
                className="shrink-0 rounded-lg border border-pin-500/30 bg-pin-500/12 px-2 py-1 font-mono text-xs font-bold text-pin-300"
                title="Points earned"
              >
                +{pointsEarned}
              </span>
            )}
            {!readOnly && (
              <div className="flex shrink-0 items-center gap-0.5">
                <button
                  onClick={onOpen}
                  aria-label={`Swap wrestler for ${label} pounds`}
                  className="rounded-lg p-2 text-ink-500 transition-colors hover:bg-mat-700 hover:text-gold-400"
                >
                  <ArrowLeftRight size={15} />
                </button>
                <button
                  onClick={onRemove}
                  aria-label={`Remove ${wrestler.name}`}
                  className="rounded-lg p-2 text-ink-500 transition-colors hover:bg-mat-700 hover:text-blood-400"
                >
                  <X size={15} />
                </button>
              </div>
            )}
          </>
        ) : (
          <button
            onClick={onOpen}
            disabled={readOnly}
            className="flex h-11 flex-1 items-center justify-center gap-2 rounded-lg border border-dashed border-mat-600 text-sm font-semibold text-ink-500 transition-colors hover:border-gold-500/50 hover:text-gold-400 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Choose wrestler
          </button>
        )}
      </div>
      {readOnly && breakdownChips.length > 0 && (
        <div className="mt-2 flex flex-wrap gap-1.5 pl-[60px]">
          {breakdownChips.map(([label, v]) => (
            <span key={label} className="rounded bg-mat-800 px-1.5 py-0.5 font-mono text-[9px] font-bold text-ink-400">
              {label} +{v}
            </span>
          ))}
        </div>
      )}
    </motion.div>
  )
}

import React from 'react'
import { motion } from 'framer-motion'
import { cn } from '../../lib/utils'

/**
 * DualBar — head-to-head stat row: side A (gold, grows left) vs side B (blood, grows right).
 * Values are raw numbers; bars scale to the max of the two (or `max` override).
 */
export default function DualBar({ label, a, b, max, format = (v) => v, className }) {
  const av = Number(a) || 0
  const bv = Number(b) || 0
  const denom = max ?? Math.max(av, bv, 1)
  const aWins = av > bv
  const bWins = bv > av
  return (
    <div className={cn('grid grid-cols-[1fr_auto_1fr] items-center gap-2 sm:gap-3', className)}>
      {/* A side — right-aligned, bar grows from center */}
      <div className="flex items-center justify-end gap-2">
        <span className={cn('font-mono text-sm font-bold', aWins ? 'text-gold-300' : 'text-ink-300')}>{format(a)}</span>
        <div className="flex h-2.5 w-full max-w-40 justify-end overflow-hidden rounded-full bg-mat-700/60">
          <motion.div
            className={cn('h-full rounded-full', aWins ? 'bg-gold-500' : 'bg-gold-500/45')}
            initial={{ width: 0 }}
            animate={{ width: `${(av / denom) * 100}%` }}
            transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
          />
        </div>
      </div>
      <span className="w-24 text-center text-[10px] font-bold uppercase tracking-[0.12em] text-ink-500 sm:w-28">{label}</span>
      {/* B side — left-aligned, bar grows from center */}
      <div className="flex items-center gap-2">
        <div className="h-2.5 w-full max-w-40 overflow-hidden rounded-full bg-mat-700/60">
          <motion.div
            className={cn('h-full rounded-full', bWins ? 'bg-blood-400' : 'bg-blood-400/45')}
            initial={{ width: 0 }}
            animate={{ width: `${(bv / denom) * 100}%` }}
            transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
          />
        </div>
        <span className={cn('font-mono text-sm font-bold', bWins ? 'text-blood-300' : 'text-ink-300')}>{format(b)}</span>
      </div>
    </div>
  )
}

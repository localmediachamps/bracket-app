import React from 'react'
import { motion } from 'framer-motion'
import { cn, pct } from '../../lib/utils'

/**
 * HBar — one labeled horizontal bar row (value 0..1).
 */
export function HBar({ label, value, detail, color = 'gold', className }) {
  const v = Math.max(0, Math.min(1, Number(value) || 0))
  const bar = color === 'pin' ? 'bg-pin-500' : color === 'blood' ? 'bg-blood-500' : 'bg-gold-500'
  const text = color === 'pin' ? 'text-pin-400' : color === 'blood' ? 'text-blood-400' : 'text-gold-400'
  return (
    <div className={cn('flex items-center gap-3', className)}>
      <span className="w-24 shrink-0 truncate text-xs font-semibold text-ink-300">{label}</span>
      <div className="h-2.5 min-w-0 flex-1 overflow-hidden rounded-full bg-mat-700/70">
        <motion.div
          className={cn('h-full rounded-full', bar)}
          initial={{ width: 0 }}
          animate={{ width: `${v * 100}%` }}
          transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
        />
      </div>
      <span className={cn('w-14 shrink-0 text-right font-mono text-xs font-bold', text)}>{pct(v)}</span>
      {detail && <span className="w-14 shrink-0 text-right font-mono text-[10px] text-ink-600">{detail}</span>}
    </div>
  )
}

/**
 * HBarList — card-ified list of HBars with empty state.
 */
export function HBarList({ rows, color = 'gold', className }) {
  if (!rows?.length) {
    return <p className="py-6 text-center text-sm text-ink-600">No data yet — score some picks first.</p>
  }
  return (
    <div className={cn('space-y-3', className)}>
      {rows.map((r, i) => (
        <HBar key={r.label ?? i} label={r.label} value={r.value} detail={r.detail} color={color} />
      ))}
    </div>
  )
}

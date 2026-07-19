import React from 'react'
import { motion } from 'framer-motion'
import { AlertTriangle, Wallet } from 'lucide-react'
import { cn } from '../../lib/utils'
import { Card } from '../ui'

/**
 * BudgetMeter — animated salary-cap bar. Turns blood + shakes when over budget.
 */
export default function BudgetMeter({ used, budget, over, selections, totalWeights }) {
  const remaining = budget - used
  const pct = budget > 0 ? Math.min(100, (used / budget) * 100) : 0
  const unpicked = Math.max(0, totalWeights - selections)
  const avg = unpicked > 0 ? Math.floor(Math.max(0, remaining) / unpicked) : 0
  return (
    <motion.div animate={over ? { x: [0, -7, 7, -4, 4, 0] } : { x: 0 }} transition={{ duration: 0.45 }}>
      <Card className={cn('p-4 transition-colors', over && 'border-blood-500/60')}>
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
          <span className="flex items-center gap-2 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
            <Wallet size={13} className="text-gold-500" /> Salary cap
          </span>
          <span className="rounded-full bg-gold-500/15 px-2 py-0.5 font-mono text-[10px] font-bold text-gold-400">
            {selections}/{totalWeights} picked
          </span>
          <span className="ml-auto font-mono text-sm font-bold text-ink-100">
            <span className={cn(over ? 'text-blood-400' : 'text-gold-400')}>{used}</span>
            <span className="text-ink-600"> / {budget} used</span>
          </span>
        </div>
        <div
          className="mt-2.5 h-2.5 overflow-hidden rounded-full bg-mat-700"
          role="progressbar"
          aria-valuenow={used}
          aria-valuemax={budget}
          aria-label="Budget used"
        >
          <motion.div
            className={cn(
              'h-full rounded-full',
              over ? 'bg-blood-500' : 'bg-gradient-to-r from-gold-600 via-gold-500 to-gold-400'
            )}
            initial={{ width: 0 }}
            animate={{ width: `${pct}%` }}
            transition={{ type: 'spring', damping: 26, stiffness: 200 }}
          />
        </div>
        <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs">
          {over ? (
            <span className="flex items-center gap-1.5 font-bold text-blood-400">
              <AlertTriangle size={13} /> Over budget by {used - budget} — remove cost to save
            </span>
          ) : (
            <span className="text-ink-400">
              <span className="font-mono font-bold text-pin-400">{remaining}</span> remaining
            </span>
          )}
          <span className="ml-auto text-ink-500">
            Avg for remaining picks: <span className="font-mono font-bold text-ink-300">{avg}</span>
          </span>
        </div>
      </Card>
    </motion.div>
  )
}

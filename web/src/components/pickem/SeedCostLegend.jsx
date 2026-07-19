import React, { useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { ChevronDown, Coins } from 'lucide-react'
import { cn } from '../../lib/utils'
import { Card } from '../ui'

/**
 * SeedCostLegend — collapsible sidebar card mirroring pickem_config.seed_costs
 * with gold gradient chips (Seed 1 → 200 … All remaining → 10).
 */
export default function SeedCostLegend({ seedCosts }) {
  const [open, setOpen] = useState(true)
  const entries = Object.entries(seedCosts ?? {})
    .filter(([k]) => k !== 'default')
    .sort((a, b) => Number(a[0]) - Number(b[0]))

  return (
    <Card>
      <button
        className="flex w-full items-center justify-between p-4"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        aria-controls="seed-cost-legend"
      >
        <span className="flex items-center gap-2 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
          <Coins size={13} className="text-gold-500" /> Seed cost legend
        </span>
        <ChevronDown size={15} className={cn('text-ink-500 transition-transform', open && 'rotate-180')} />
      </button>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            id="seed-cost-legend"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.22 }}
            className="overflow-hidden"
          >
            <div className="grid grid-cols-2 gap-1.5 px-4 pb-4">
              {entries.map(([seed, cost]) => (
                <div
                  key={seed}
                  className="flex items-center justify-between rounded-lg border border-gold-500/20 bg-gradient-to-br from-gold-500/12 to-gold-600/5 px-2.5 py-1.5"
                >
                  <span className="text-[11px] font-bold text-ink-300">Seed {seed}</span>
                  <span className="font-mono text-[11px] font-bold text-gold-300">{cost}</span>
                </div>
              ))}
              {seedCosts?.default != null && (
                <div className="col-span-2 flex items-center justify-between rounded-lg border border-mat-600 bg-mat-800 px-2.5 py-1.5">
                  <span className="text-[11px] font-bold text-ink-400">All remaining seeds</span>
                  <span className="font-mono text-[11px] font-bold text-gold-300">{seedCosts.default}</span>
                </div>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </Card>
  )
}

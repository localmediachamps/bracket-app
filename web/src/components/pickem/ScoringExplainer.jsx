import React, { useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { ChevronDown, Info } from 'lucide-react'
import { cn, VICTORY_TYPES } from '../../lib/utils'
import { Card } from '../ui'

const PLACE_LABELS = ['1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th']

/**
 * ScoringExplainer — collapsible card rendering pickem_config.scoring as pretty
 * mini-tables: placement points, win points, bonus points.
 */
export default function ScoringExplainer({ scoring }) {
  const [open, setOpen] = useState(false)
  const placement = scoring?.placement_points ?? {}
  const winPoints = scoring?.win_points ?? {}
  const bonus = scoring?.bonus_points ?? {}
  const placementEntries = Object.entries(placement).sort((a, b) => Number(a[0]) - Number(b[0]))

  return (
    <Card>
      <button
        className="flex w-full items-center justify-between p-4"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        aria-controls="scoring-explainer"
      >
        <span className="flex items-center gap-2 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
          <Info size={13} className="text-gold-500" /> How points are earned
        </span>
        <ChevronDown size={15} className={cn('text-ink-500 transition-transform', open && 'rotate-180')} />
      </button>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            id="scoring-explainer"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.22 }}
            className="overflow-hidden"
          >
            <div className="space-y-4 px-4 pb-4 text-xs">
              <section>
                <p className="mb-1.5 font-bold uppercase tracking-wider text-ink-500">Final placement</p>
                <div className="overflow-hidden rounded-lg border border-mat-700">
                  {placementEntries.map(([place, pts], i) => (
                    <div
                      key={place}
                      className={cn('flex items-center justify-between px-3 py-1.5', i % 2 === 0 ? 'bg-mat-800/50' : 'bg-mat-850')}
                    >
                      <span className="font-semibold text-ink-300">{PLACE_LABELS[Number(place) - 1] ?? `${place}th`} place</span>
                      <span className="font-mono font-bold text-gold-300">+{pts}</span>
                    </div>
                  ))}
                  {placementEntries.length === 0 && <p className="px-3 py-2 text-ink-500">No placement points configured.</p>}
                </div>
              </section>

              <section>
                <p className="mb-1.5 font-bold uppercase tracking-wider text-ink-500">Per win</p>
                <div className="overflow-hidden rounded-lg border border-mat-700">
                  {Object.entries(winPoints).map(([section, pts], i) => (
                    <div
                      key={section}
                      className={cn('flex items-center justify-between px-3 py-1.5', i % 2 === 0 ? 'bg-mat-800/50' : 'bg-mat-850')}
                    >
                      <span className="font-semibold capitalize text-ink-300">{section} win</span>
                      <span className="font-mono font-bold text-pin-300">+{pts}</span>
                    </div>
                  ))}
                </div>
              </section>

              <section>
                <p className="mb-1.5 font-bold uppercase tracking-wider text-ink-500">Bonus per win type</p>
                <div className="overflow-hidden rounded-lg border border-mat-700">
                  {Object.entries(bonus).map(([type, pts], i) => (
                    <div
                      key={type}
                      className={cn('flex items-center justify-between px-3 py-1.5', i % 2 === 0 ? 'bg-mat-800/50' : 'bg-mat-850')}
                    >
                      <span className="font-semibold text-ink-300">{VICTORY_TYPES[type]?.name ?? type}</span>
                      <span className="font-mono font-bold text-gold-300">+{pts}</span>
                    </div>
                  ))}
                </div>
              </section>

              <p className="text-[11px] leading-relaxed text-ink-500">
                Your wrestler earns placement points for where they finish, points for every win, and bonuses for
                dominant victories. Entry total = the sum of all your wrestlers.
              </p>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </Card>
  )
}

import React from 'react'
import { Check } from 'lucide-react'
import { cn } from '../../lib/utils'
import { ProgressRing } from '../ui'

/**
 * WeightRail — sticky horizontal pill tabs, one per weight class, each with a
 * ProgressRing of the user's picks in that weight (once loaded).
 */
export default function WeightRail({ weightClasses, activeId, onSelect, stats }) {
  if (!weightClasses?.length) return null
  return (
    <div className="sticky top-16 z-30 -mx-4 border-b border-mat-800 bg-mat-950/90 px-4 py-2.5 backdrop-blur-md">
      <div className="flex gap-2 overflow-x-auto no-scrollbar" role="tablist" aria-label="Weight classes">
        {weightClasses.map((wc) => {
          const active = wc.id === activeId
          const st = stats?.get(wc.id)
          const v = st && st.total > 0 ? st.picked / st.total : null
          return (
            <button
              key={wc.id}
              role="tab"
              aria-selected={active}
              onClick={() => onSelect(wc.id)}
              className={cn(
                'flex shrink-0 items-center gap-2 rounded-full border px-3.5 py-1.5 text-sm font-bold transition-all',
                active
                  ? 'border-gold-500/60 bg-gold-500/12 text-gold-300 shadow-glow-sm'
                  : 'border-mat-600 bg-mat-850 text-ink-400 hover:border-mat-500 hover:text-ink-100'
              )}
            >
              {v != null && (
                <ProgressRing value={v} size={20} stroke={2.5}>
                  {v >= 1 ? <Check size={10} strokeWidth={4} className="text-pin-400" /> : ''}
                </ProgressRing>
              )}
              {wc.weight ?? wc.name}
            </button>
          )
        })}
      </div>
    </div>
  )
}

import React from 'react'
import { cn } from '../../lib/utils'
import { ProgressRing } from '../ui'

/**
 * Horizontal weight-class pill rail.
 * props:
 *  weights   [{id, weight, name, competitor_count?, progress? (0..1)}]
 *  activeId
 *  onChange(id)
 */
export default function WeightTabs({ weights, activeId, onChange, className }) {
  if (!weights?.length) return null
  return (
    <div className={cn('flex gap-1.5 overflow-x-auto no-scrollbar rounded-xl border border-mat-700 bg-mat-850 p-1.5', className)} role="tablist" aria-label="Weight classes">
      {weights.map((w) => {
        const active = w.id === activeId
        return (
          <button
            key={w.id}
            role="tab"
            aria-selected={active}
            onClick={() => onChange(w.id)}
            className={cn(
              'flex shrink-0 items-center gap-2 rounded-lg px-3 py-2 font-mono text-sm font-bold transition-colors',
              active ? 'bg-gold-500 text-mat-950 shadow-glow-sm' : 'text-ink-400 hover:bg-mat-800 hover:text-ink-100'
            )}
          >
            {w.progress !== undefined && (
              <ProgressRing value={w.progress} size={22} stroke={2.5}>
                <span className="sr-only">{Math.round(w.progress * 100)}%</span>
              </ProgressRing>
            )}
            {w.weight}
            <span className={cn('text-[10px] font-sans font-semibold', active ? 'text-mat-800' : 'text-ink-600')}>lbs</span>
            {w.competitor_count !== undefined && (
              <span className={cn('rounded-full px-1.5 py-px text-[10px] font-bold', active ? 'bg-mat-950/15 text-mat-900' : 'bg-mat-700 text-ink-500')}>
                {w.competitor_count}
              </span>
            )}
          </button>
        )
      })}
    </div>
  )
}

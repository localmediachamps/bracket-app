import React from 'react'
import { Check } from 'lucide-react'
import { ProgressRing } from '../ui'
import { cn } from '../../lib/utils'

/**
 * WeightRail — horizontal scrollable pill tabs, one per weight class.
 * stats: { [weightClassId]: { done, total } } — rendered as a ProgressRing
 * when known (i.e. once that weight's bracket data has been loaded).
 */
export default function WeightRail({ weights, activeId, onChange, stats = {} }) {
  return (
    <div className="no-scrollbar -mx-1 flex gap-2 overflow-x-auto px-1 pb-2" role="tablist" aria-label="Weight classes">
      {weights.map((w) => {
        const active = w.id === activeId
        const st = stats[w.id]
        const complete = st && st.total > 0 && st.done >= st.total
        return (
          <button
            key={w.id}
            role="tab"
            aria-selected={active}
            onClick={() => onChange(w.id)}
            className={cn(
              'flex shrink-0 items-center gap-2 rounded-full border px-3.5 py-2 text-sm font-bold transition-all',
              active
                ? 'border-gold-500/60 bg-gold-500/12 text-gold-300 shadow-glow-sm'
                : 'border-mat-600 bg-mat-850 text-ink-400 hover:border-mat-500 hover:text-ink-100'
            )}
          >
            {st && (
              <ProgressRing value={st.total ? st.done / st.total : 0} size={22} stroke={2.5}>
                {complete ? <Check size={10} strokeWidth={3.5} className="text-pin-400" /> : null}
              </ProgressRing>
            )}
            {w.weight != null ? (
              <>
                <span className="font-mono">{w.weight}</span>
                <span className="text-[10px] font-semibold uppercase tracking-wider text-ink-600">lbs</span>
              </>
            ) : (
              <span>{w.name ?? `Weight ${w.id}`}</span>
            )}
            {w.status === 'completed' && !st && <Check size={12} className="text-pin-400" />}
          </button>
        )
      })}
    </div>
  )
}

import React from 'react'

/**
 * Donut — hand-rolled SVG donut chart.
 * props:
 *  segments — [{ value, color, label }] (values need not sum to anything; normalized internally)
 *  size, stroke — geometry
 *  center — node rendered in the middle (big number)
 *  sub — small node under center
 */
export default function Donut({ segments = [], size = 160, stroke = 18, center, sub, className }) {
  const total = segments.reduce((s, x) => s + (Number(x.value) || 0), 0)
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  let offset = 0

  return (
    <div className={className} style={{ width: size }}>
      <div className="relative" style={{ width: size, height: size }}>
        <svg width={size} height={size} className="-rotate-90" role="img" aria-label={segments.map((s) => `${s.label}: ${s.value}`).join(', ')}>
          <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--color-mat-700)" strokeWidth={stroke} />
          {total > 0 &&
            segments.map((s, i) => {
              const frac = (Number(s.value) || 0) / total
              const dash = Math.max(0, frac * c - (frac > 0 ? 2 : 0))
              const gap = c - dash
              const el = (
                <circle
                  key={i}
                  cx={size / 2}
                  cy={size / 2}
                  r={r}
                  fill="none"
                  stroke={s.color}
                  strokeWidth={stroke}
                  strokeDasharray={`${dash} ${gap}`}
                  strokeDashoffset={-offset * c}
                  strokeLinecap="butt"
                  style={{ transition: 'stroke-dashoffset 0.6s cubic-bezier(0.22,1,0.36,1), stroke-dasharray 0.6s cubic-bezier(0.22,1,0.36,1)' }}
                />
              )
              offset += frac
              return el
            })}
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
          {center}
          {sub && <div className="mt-0.5 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">{sub}</div>}
        </div>
      </div>
      {segments.length > 1 && (
        <div className="mt-3 flex flex-wrap items-center justify-center gap-x-4 gap-y-1.5">
          {segments.map((s, i) => (
            <span key={i} className="inline-flex items-center gap-1.5 text-xs font-semibold text-ink-300">
              <span className="h-2.5 w-2.5 rounded-sm" style={{ background: s.color }} />
              {s.label}
              <span className="font-mono text-ink-500">{s.value}</span>
            </span>
          ))}
        </div>
      )}
    </div>
  )
}

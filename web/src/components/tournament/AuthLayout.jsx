import React from 'react'
import { Quote } from 'lucide-react'
import { Card } from '../ui'

/** Small decorative bracket tree used on the auth brand panel. */
function BracketArt() {
  const paths = [
    // left half: 4 -> 2 -> 1
    'M 0 12 H 26 V 36 M 0 36 H 26 M 26 24 H 52',
    'M 0 60 H 26 V 84 M 0 84 H 26 M 26 72 H 52',
    'M 52 24 H 78 V 72 M 52 72 H 78 M 78 48 H 104',
    // right half (mirrored)
    'M 320 12 H 294 V 36 M 320 36 H 294 M 294 24 H 268',
    'M 320 60 H 294 V 84 M 320 84 H 294 M 294 72 H 268',
    'M 268 24 H 242 V 72 M 268 72 H 242 M 242 48 H 216',
    // final connector
    'M 104 48 H 216',
  ]
  return (
    <svg viewBox="0 0 320 96" className="w-full max-w-md opacity-50" aria-hidden="true">
      {paths.map((d, i) => (
        <path
          key={i}
          d={d}
          fill="none"
          stroke={i === paths.length - 1 ? 'var(--color-gold-500)' : 'var(--color-mat-500)'}
          strokeWidth={i === paths.length - 1 ? 2 : 1.25}
        />
      ))}
      <circle cx="160" cy="48" r="4" fill="var(--color-gold-500)" />
    </svg>
  )
}

/**
 * AuthLayout — split layout for login/register:
 * left brand panel (quote + bracket art, hidden on mobile), right form card.
 */
export default function AuthLayout({ quote, attribution, title, sub, children, footer }) {
  return (
    <div className="mx-auto grid w-full max-w-5xl items-stretch gap-6 py-4 sm:py-8 lg:grid-cols-[1.05fr_1fr]">
      <aside className="relative hidden overflow-hidden rounded-2xl border border-mat-700 bg-mat-900 p-10 lg:flex lg:flex-col">
        <div className="bg-arena absolute inset-0" aria-hidden="true" />
        <div className="relative">
          <span className="mb-6 flex h-11 w-11 items-center justify-center rounded-xl bg-gold-500/12 text-gold-400">
            <Quote size={20} />
          </span>
          <blockquote className="font-display text-2xl uppercase leading-tight tracking-tight text-ink-100 xl:text-3xl">
            {quote}
          </blockquote>
          {attribution && <p className="mt-4 text-sm font-semibold text-ink-500">{attribution}</p>}
        </div>
        <div className="relative mt-auto pt-12">
          <BracketArt />
          <p className="mt-4 font-mono text-[10px] uppercase tracking-[0.2em] text-ink-600">
            61 matches · 33 seeds · one champion
          </p>
        </div>
      </aside>

      <Card className="p-6 sm:p-8">
        <h1 className="font-display text-xl uppercase tracking-wide text-ink-100">{title}</h1>
        {sub && <p className="mt-1 text-sm text-ink-500">{sub}</p>}
        <div className="mt-6">{children}</div>
        {footer && <div className="mt-6 border-t border-mat-700 pt-4 text-center text-sm text-ink-500">{footer}</div>}
      </Card>
    </div>
  )
}

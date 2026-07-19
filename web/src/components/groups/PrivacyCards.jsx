import React from 'react'
import { Globe, Link2, Lock } from 'lucide-react'
import { cn } from '../../lib/utils'

export const PRIVACY_OPTIONS = [
  {
    key: 'public',
    icon: Globe,
    label: 'Public',
    blurb: 'Listed on the tournament page. Anyone can find and join.',
  },
  {
    key: 'unlisted',
    icon: Link2,
    label: 'Unlisted',
    blurb: 'Hidden from the directory. Anyone with the invite code or link can join.',
  },
  {
    key: 'private',
    icon: Lock,
    label: 'Private',
    blurb: 'Invite code required. Members and leaderboard hidden from outsiders.',
  },
]

/**
 * PrivacyCards — radio-card selector for group privacy.
 */
export default function PrivacyCards({ value, onChange }) {
  return (
    <div role="radiogroup" aria-label="Group privacy" className="grid gap-2 sm:grid-cols-3">
      {PRIVACY_OPTIONS.map((opt) => {
        const active = value === opt.key
        return (
          <button
            key={opt.key}
            type="button"
            role="radio"
            aria-checked={active}
            onClick={() => onChange(opt.key)}
            className={cn(
              'flex flex-col gap-1.5 rounded-xl border p-3.5 text-left transition-all',
              active
                ? 'border-gold-500 bg-gold-500/10 shadow-glow-sm'
                : 'border-mat-600 bg-mat-800 hover:border-mat-500 hover:bg-mat-750'
            )}
          >
            <span className={cn('flex items-center gap-2 text-sm font-bold', active ? 'text-gold-400' : 'text-ink-100')}>
              <opt.icon size={15} />
              {opt.label}
            </span>
            <span className="text-xs leading-relaxed text-ink-500">{opt.blurb}</span>
          </button>
        )
      })}
    </div>
  )
}

import React from 'react'
import { cn } from '../../lib/utils'

export const GROUP_EMOJIS = ['🤼', '🏆', '🥇', '💪', '🔥', '⚡', '🎯', '🐺', '🦁', '🐻', '⚔️', '🛡️']

/**
 * EmojiPicker — grid of wrestling-ish emojis, radio behavior.
 */
export default function EmojiPicker({ value, onChange, emojis = GROUP_EMOJIS }) {
  return (
    <div role="radiogroup" aria-label="Group avatar emoji" className="grid grid-cols-6 gap-2">
      {emojis.map((e) => {
        const active = value === e
        return (
          <button
            key={e}
            type="button"
            role="radio"
            aria-checked={active}
            aria-label={`Emoji ${e}`}
            onClick={() => onChange(e)}
            className={cn(
              'flex h-11 items-center justify-center rounded-xl border text-xl transition-all',
              active
                ? 'border-gold-500 bg-gold-500/15 shadow-glow-sm scale-105'
                : 'border-mat-600 bg-mat-800 hover:border-mat-500 hover:bg-mat-750'
            )}
          >
            {e}
          </button>
        )
      })}
    </div>
  )
}

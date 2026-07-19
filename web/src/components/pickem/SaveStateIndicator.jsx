import React from 'react'
import { AlertTriangle, Check, Loader2 } from 'lucide-react'
import { cn } from '../../lib/utils'
import { Button } from '../ui'

/**
 * SaveStateIndicator — autosave status chip for the pick'em editor header.
 * states: saved | saving | retrying | error | blocked
 */
export default function SaveStateIndicator({ state = 'saved', onRetry, className }) {
  if (state === 'error') {
    return (
      <span className={cn('flex items-center gap-2', className)} role="status" aria-live="polite">
        <span className="flex items-center gap-1 text-xs font-bold text-blood-400">
          <AlertTriangle size={13} /> Save failed
        </span>
        <Button variant="danger" size="xs" onClick={onRetry}>
          Retry
        </Button>
      </span>
    )
  }
  const map = {
    saved: { icon: Check, cls: 'text-pin-400', label: 'Saved' },
    saving: { icon: Loader2, cls: 'text-ink-400', label: 'Saving…', spin: true },
    retrying: { icon: Loader2, cls: 'text-blood-400', label: 'Save failed — retrying', spin: true },
    blocked: { icon: AlertTriangle, cls: 'text-blood-400', label: 'Not saved — over budget' },
  }
  const s = map[state] ?? map.saved
  return (
    <span className={cn('flex items-center gap-1.5 text-xs font-bold', s.cls, className)} role="status" aria-live="polite">
      <s.icon size={13} className={s.spin ? 'animate-spin' : ''} aria-hidden />
      {s.label}
    </span>
  )
}

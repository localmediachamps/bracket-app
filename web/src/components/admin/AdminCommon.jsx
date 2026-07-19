import React from 'react'
import { AlertTriangle, RefreshCw } from 'lucide-react'
import { Button, Card, Modal, Textarea } from '../ui'
import { cn } from '../../lib/utils'

/** Page header row for admin pages. */
export function PageHeader({ title, sub, actions, className }) {
  return (
    <div className={cn('mb-6 flex flex-wrap items-end justify-between gap-3', className)}>
      <div className="min-w-0">
        <h1 className="font-display text-xl uppercase tracking-wide text-ink-100 sm:text-2xl">{title}</h1>
        {sub && <p className="mt-1 text-sm text-ink-500">{sub}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  )
}

/** Error card with retry. */
export function ErrorState({ error, onRetry, title = 'Failed to load' }) {
  return (
    <Card className="flex flex-col items-center gap-3 border-blood-500/40 px-6 py-10 text-center">
      <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-blood-500/15 text-blood-400">
        <AlertTriangle size={22} />
      </span>
      <div>
        <p className="font-display text-sm uppercase tracking-wide text-ink-100">{title}</p>
        <p className="mt-1 max-w-md text-sm text-ink-500">{error?.payload?.message || error?.message || 'Unexpected error'}</p>
      </div>
      {onRetry && (
        <Button variant="secondary" size="sm" onClick={onRetry}>
          <RefreshCw size={14} /> Retry
        </Button>
      )}
    </Card>
  )
}

/** Thin gold progress bar. */
export function ProgressBar({ value, className, tone = 'gold' }) {
  const v = Math.max(0, Math.min(1, value ?? 0))
  return (
    <div className={cn('h-1.5 w-full overflow-hidden rounded-full bg-mat-700', className)} role="progressbar" aria-valuenow={Math.round(v * 100)} aria-valuemin={0} aria-valuemax={100}>
      <div
        className={cn('h-full rounded-full transition-all duration-500', tone === 'pin' ? 'bg-pin-500' : tone === 'blood' ? 'bg-blood-500' : 'bg-gold-500')}
        style={{ width: `${v * 100}%` }}
      />
    </div>
  )
}

/**
 * Shared confirm modal — optional required reason input.
 * props: open, onClose, onConfirm(reason), title, body, confirmLabel, danger, loading, requireReason, reasonPlaceholder
 */
export function ConfirmModal({ open, onClose, onConfirm, title, body, confirmLabel = 'Confirm', danger, loading, requireReason, reasonPlaceholder = 'Reason (required)…', children }) {
  const [reason, setReason] = React.useState('')
  React.useEffect(() => {
    if (open) setReason('')
  }, [open])
  const blocked = requireReason && !reason.trim()
  return (
    <Modal open={open} onClose={loading ? undefined : onClose} title={title}>
      <div className="space-y-4">
        {typeof body === 'string' ? <p className="text-sm text-ink-300">{body}</p> : body}
        {children}
        {requireReason && (
          <Textarea
            rows={2}
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder={reasonPlaceholder}
            aria-label="Reason"
          />
        )}
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose} disabled={loading}>Cancel</Button>
          <Button
            variant={danger ? 'danger' : 'primary'}
            loading={loading}
            disabled={blocked}
            onClick={() => onConfirm(requireReason ? reason.trim() : undefined)}
          >
            {confirmLabel}
          </Button>
        </div>
      </div>
    </Modal>
  )
}

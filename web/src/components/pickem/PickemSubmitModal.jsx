import React from 'react'
import { AlertTriangle, Lock, Send } from 'lucide-react'
import { Button, Countdown, Modal } from '../ui'

/**
 * PickemSubmitModal — summary confirmation: picks list, total cost, remaining
 * budget, tiebreakers, lock warning.
 */
export default function PickemSubmitModal({ open, onClose, rows, used, budget, tiebreakers, tiebreakerConfig, onConfirm, submitting, missingCount, locksAt }) {
  const remaining = budget - used
  const tbEntries = (tiebreakerConfig ?? []).filter((t) => tiebreakers?.[t.key] !== '' && tiebreakers?.[t.key] != null)
  return (
    <Modal open={open} onClose={onClose} title="Submit Pick'em" wide>
      <p className="mb-3 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">Your roster</p>
      <div className="space-y-1.5">
        {rows.map(({ wc, wrestler, cost }) => (
          <div key={wc.id} className="flex items-center gap-2.5 rounded-lg border border-mat-700 bg-mat-800/60 px-3 py-2">
            <span className="w-9 shrink-0 font-mono text-xs font-bold text-gold-400">{wc.weight ?? wc.name}</span>
            {wrestler ? (
              <span className="min-w-0 flex-1 leading-tight">
                <span className="block truncate text-xs font-semibold text-ink-100">
                  <span className="mr-1 font-mono text-[10px] text-gold-500">#{wrestler.seed}</span>
                  {wrestler.name}
                </span>
                <span className="block truncate text-[10px] text-ink-500">{wrestler.school}</span>
              </span>
            ) : (
              <span className="flex-1 text-xs italic text-blood-400">No wrestler picked</span>
            )}
            <span className="shrink-0 rounded border border-gold-500/30 bg-gold-500/12 px-1.5 py-0.5 font-mono text-[10px] font-bold text-gold-300">
              {cost}
            </span>
          </div>
        ))}
      </div>

      <div className="mt-3 flex items-center justify-between rounded-lg border border-mat-700 bg-mat-800 px-3 py-2.5 text-sm">
        <span className="font-semibold text-ink-400">Total cost</span>
        <span className="font-mono font-bold text-ink-100">
          <span className="text-gold-400">{used}</span>
          <span className="text-ink-600"> / {budget}</span>
          <span className="ml-3 text-pin-400">{remaining} left</span>
        </span>
      </div>

      {tbEntries.length > 0 && (
        <div className="mt-2 flex flex-wrap gap-2">
          {tbEntries.map((t) => (
            <span key={t.key} className="rounded-full border border-mat-600 bg-mat-800 px-2.5 py-1 font-mono text-[10px] font-bold text-ink-300">
              {t.label}: <span className="text-gold-300">{tiebreakers[t.key]}</span>
            </span>
          ))}
        </div>
      )}

      {missingCount != null && (
        <p className="mt-3 flex items-center gap-2 rounded-lg border border-blood-500/40 bg-blood-500/10 px-3 py-2.5 text-xs font-semibold text-blood-400">
          <AlertTriangle size={14} className="shrink-0" />
          {missingCount} {missingCount === 1 ? 'weight class still needs' : 'weight classes still need'} a wrestler.
        </p>
      )}

      <div className="mt-4 flex items-center gap-2.5 rounded-lg border border-gold-500/30 bg-gold-500/8 px-3 py-2.5 text-xs text-ink-300">
        <Lock size={14} className="shrink-0 text-gold-400" />
        <span>
          You can keep editing until the deadline, then your picks lock. Locks in <Countdown to={locksAt} className="text-xs" />
        </span>
      </div>

      <div className="mt-5 flex justify-end gap-2">
        <Button variant="ghost" onClick={onClose}>
          Keep editing
        </Button>
        <Button onClick={onConfirm} loading={submitting}>
          <Send size={14} /> Submit Pick'em
        </Button>
      </div>
    </Modal>
  )
}

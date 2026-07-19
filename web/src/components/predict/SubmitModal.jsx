import React from 'react'
import { AlertTriangle, Lock, Send } from 'lucide-react'
import { Button, Countdown, Modal } from '../ui'

/**
 * SubmitModal — review-your-champions confirmation before submitting a bracket.
 */
export default function SubmitModal({ open, onClose, champions, onConfirm, submitting, missingCount, locksAt }) {
  return (
    <Modal open={open} onClose={onClose} title="Submit your bracket" wide>
      <p className="mb-3 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">Your predicted champions</p>
      <div className="grid gap-2 sm:grid-cols-2">
        {champions.map(({ wc, comp }) => (
          <div key={wc.id} className="flex items-center gap-2.5 rounded-lg border border-mat-700 bg-mat-800/60 px-3 py-2">
            <span className="w-9 shrink-0 font-mono text-xs font-bold text-gold-400">{wc.weight ?? wc.name}</span>
            {comp ? (
              <span className="min-w-0 flex-1 leading-tight">
                <span className="block truncate text-xs font-semibold text-ink-100">
                  <span className="mr-1 font-mono text-[10px] text-gold-500">#{comp.seed}</span>
                  {comp.name}
                </span>
                <span className="block truncate text-[10px] text-ink-500">{comp.school}</span>
              </span>
            ) : (
              <span className="flex-1 text-xs italic text-ink-600">—</span>
            )}
          </div>
        ))}
      </div>

      {missingCount != null && (
        <p className="mt-3 flex items-center gap-2 rounded-lg border border-blood-500/40 bg-blood-500/10 px-3 py-2.5 text-xs font-semibold text-blood-400">
          <AlertTriangle size={14} className="shrink-0" />
          The server says {missingCount} {missingCount === 1 ? 'match is' : 'matches are'} still missing picks. If you just
          finished picking, wait for “Saved” and try again — or find gaps via “My Champs”.
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
          <Send size={14} /> Submit bracket
        </Button>
      </div>
    </Modal>
  )
}

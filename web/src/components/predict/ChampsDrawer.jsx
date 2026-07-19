import React from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { ChevronRight, Crown, ListChecks, X } from 'lucide-react'
import { cn } from '../../lib/utils'
import { ProgressRing } from '../ui'

/**
 * ChampsDrawer — "My Champs" panel: right drawer on desktop, bottom sheet on
 * mobile. Shows the predicted champion per weight, per-weight progress rings,
 * and the list of unresolved matches (click jumps to the match).
 */
export default function ChampsDrawer({ open, onClose, champions, unresolved, railStats, progress, onJump }) {
  const bodyProps = { onClose, champions, unresolved, railStats, progress, onJump }
  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            key="backdrop"
            className="fixed inset-0 z-40 bg-mat-950/70 backdrop-blur-sm lg:hidden"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />
          {/* mobile bottom sheet */}
          <motion.div
            key="sheet"
            role="dialog"
            aria-label="My champions summary"
            className="fixed inset-x-0 bottom-0 z-50 flex max-h-[80vh] flex-col rounded-t-2xl border-t border-mat-600 bg-mat-850 shadow-card lg:hidden"
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 30, stiffness: 320 }}
          >
            <DrawerBody {...bodyProps} />
          </motion.div>
          {/* desktop right drawer */}
          <motion.div
            key="drawer"
            role="dialog"
            aria-label="My champions summary"
            className="fixed bottom-0 right-0 top-16 z-50 hidden w-[380px] flex-col border-l border-mat-600 bg-mat-850 shadow-card lg:flex"
            initial={{ x: '100%' }}
            animate={{ x: 0 }}
            exit={{ x: '100%' }}
            transition={{ type: 'spring', damping: 30, stiffness: 320 }}
          >
            <DrawerBody {...bodyProps} />
          </motion.div>
        </>
      )}
    </AnimatePresence>
  )
}

function DrawerBody({ onClose, champions, unresolved, railStats, progress, onJump }) {
  const champsPicked = champions.filter((c) => c.comp).length
  const pct = progress.total > 0 ? Math.min(100, (progress.picked / progress.total) * 100) : 0
  return (
    <>
      <div className="flex items-center justify-between border-b border-mat-700 px-4 py-3.5">
        <h3 className="flex items-center gap-2 font-display text-sm uppercase tracking-wide text-ink-100">
          <Crown size={15} className="text-gold-500" /> My Champs
        </h3>
        <button
          onClick={onClose}
          aria-label="Close panel"
          className="rounded-lg p-1.5 text-ink-500 hover:bg-mat-700 hover:text-ink-100"
        >
          <X size={17} />
        </button>
      </div>

      <div className="flex-1 space-y-5 overflow-y-auto p-4">
        <section>
          <p className="mb-2 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
            Predicted champions · {champsPicked}/{champions.length}
          </p>
          <div className="space-y-1.5">
            {champions.map(({ wc, loaded, comp }) => {
              const st = railStats?.get(wc.id)
              const v = st && st.total > 0 ? st.picked / st.total : null
              return (
                <div key={wc.id} className="flex items-center gap-3 rounded-lg border border-mat-700 bg-mat-800/60 px-3 py-2">
                  {v != null ? (
                    <ProgressRing value={v} size={26} stroke={3}>
                      {v >= 1 ? <span className="text-[9px] text-pin-400">✓</span> : ''}
                    </ProgressRing>
                  ) : (
                    <span className="flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded-full border border-mat-700 text-[10px] text-ink-600">
                      –
                    </span>
                  )}
                  <span className="w-10 shrink-0 font-mono text-xs font-bold text-gold-400">{wc.weight ?? wc.name}</span>
                  {comp ? (
                    <span className="min-w-0 flex-1 leading-tight">
                      <span className="block truncate text-xs font-semibold text-ink-100">
                        <span className="mr-1 font-mono text-[10px] text-gold-500">#{comp.seed}</span>
                        {comp.name}
                      </span>
                      <span className="block truncate text-[10px] text-ink-500">{comp.school}</span>
                    </span>
                  ) : (
                    <span className="flex-1 text-xs italic text-ink-600">{loaded ? '—' : 'Open weight to pick'}</span>
                  )}
                </div>
              )
            })}
          </div>
        </section>

        <section>
          <p className="mb-2 flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
            <ListChecks size={12} /> Unresolved matches · {unresolved.length}
          </p>
          {unresolved.length === 0 ? (
            <p className="rounded-lg border border-pin-500/30 bg-pin-500/8 px-3 py-2.5 text-xs font-semibold text-pin-400">
              Every loaded match has a pick.
            </p>
          ) : (
            <div className="space-y-1">
              {unresolved.slice(0, 60).map((u) => (
                <button
                  key={u.match.id}
                  onClick={() => onJump(u.weightId, u.match.id)}
                  className="flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-xs text-ink-300 transition-colors hover:bg-mat-800 hover:text-gold-300"
                  aria-label={`Go to ${u.match.round_label} match ${u.match.match_number}, ${u.weightLabel} pounds`}
                >
                  <span className="w-9 shrink-0 font-mono text-[10px] font-bold text-gold-500">{u.weightLabel}</span>
                  <span className="flex-1 truncate">
                    {u.match.round_label} · Match {u.match.match_number}
                  </span>
                  <ChevronRight size={13} className="shrink-0 text-ink-600" />
                </button>
              ))}
              {unresolved.length > 60 && (
                <p className="px-2.5 py-1 text-[10px] text-ink-600">+ {unresolved.length - 60} more — keep picking!</p>
              )}
            </div>
          )}
        </section>
      </div>

      <div className="border-t border-mat-700 px-4 py-3">
        <div className="flex items-center justify-between text-xs">
          <span className="font-semibold text-ink-500">Overall progress</span>
          <span className="font-mono font-bold text-ink-200">
            {progress.picked}
            <span className="text-ink-600">/{progress.total}</span>
          </span>
        </div>
        <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-mat-700">
          <div
            className={cn('h-full rounded-full transition-all duration-500', progress.complete ? 'bg-pin-500' : 'bg-gold-500')}
            style={{ width: `${pct}%` }}
          />
        </div>
      </div>
    </>
  )
}

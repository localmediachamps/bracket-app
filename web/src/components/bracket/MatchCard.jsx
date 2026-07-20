import React from 'react'
import { motion } from 'framer-motion'
import { Check, X, Trophy, Ban } from 'lucide-react'
import { cn, victoryLabel } from '../../lib/utils'
import { METRICS } from './bracketMath'

/**
 * MatchCard — one match in the bracket. Purely presentational.
 * props:
 *  match        — server match object
 *  mode         — predict | results | readonly | compare | admin
 *  resolved     — {top, bottom} competitors after pick resolution (predict mode)
 *  pickedId     — user's picked wrestler id for this match (predict mode)
 *  onPick       — (match, wrestlerId|null) => void
 *  highlightPath — 'gold' | 'green' | null (connector emphasis)
 *  comparePick  — { aId, bId, aPick, bPick } for compare mode
 */
export default function MatchCard({ match, mode = 'readonly', resolved, pickedId, onPick, comparePick, fluid }) {
  const top = mode === 'predict' ? resolved?.top : match.top?.competitor
  const bottom = mode === 'predict' ? resolved?.bottom : match.bottom?.competitor
  const isFinal = match.round_code === 'champ_finals'
  const interactive = mode === 'predict' && match.status !== 'complete' && match.status !== 'corrected' && !match.is_bye

  const officialWinner = match.winner_competitor_id
  const userPick = match.user_pick

  return (
    <div
      data-match-id={match.id}
      className={cn(
        'relative select-none rounded-lg border bg-mat-850 transition-all duration-150',
        isFinal ? 'border-gold-500/50 shadow-glow-sm' : 'border-mat-600',
        match.is_bye && 'opacity-70',
        match.status === 'in_progress' && 'border-blood-500/60',
      )}
      style={{ width: fluid ? '100%' : METRICS.MATCH_W, height: METRICS.MATCH_H }}
    >
      {/* match meta strip */}
      <div className="absolute -top-2 left-2 z-10 flex items-center gap-1">
        <span className={cn(
          'rounded px-1.5 py-px font-mono text-[9px] font-bold',
          isFinal ? 'bg-gold-500 text-mat-950' : 'bg-mat-700 text-ink-400'
        )}>
          {isFinal ? <span className="inline-flex items-center gap-0.5"><Trophy size={8} /> FINAL</span> : `#${match.match_number}`}
        </span>
        {match.status === 'in_progress' && (
          <span className="flex items-center gap-1 rounded bg-blood-500 px-1.5 py-px text-[9px] font-bold text-white">
            <span className="h-1 w-1 rounded-full bg-white animate-pulse-dot" /> LIVE
          </span>
        )}
        {(match.status === 'complete' || match.status === 'corrected') && (match.victory_type || match.score) && (
          <span className="rounded bg-mat-700 px-1.5 py-px font-mono text-[9px] font-bold text-pin-400">
            {victoryLabel(match.victory_type)}{match.score ? ` ${match.score}` : ''}
          </span>
        )}
      </div>

      <Slot
        comp={top}
        slot="top"
        match={match}
        mode={mode}
        interactive={interactive && !!top && !top.unknown}
        picked={pickedId != null && pickedId === top?.id}
        officialWinner={officialWinner}
        userPick={userPick}
        onPick={onPick}
        rounded="top"
      />
      <div className="mx-2 border-t border-mat-700/80" />
      <Slot
        comp={bottom}
        slot="bottom"
        match={match}
        mode={mode}
        interactive={interactive && !!bottom && !bottom.unknown}
        picked={pickedId != null && pickedId === bottom?.id}
        officialWinner={officialWinner}
        userPick={userPick}
        onPick={onPick}
        rounded="bottom"
      />

      {match.is_bye && (
        <span className="absolute right-2 top-1/2 -translate-y-1/2 rounded bg-mat-700 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-ink-500">
          Bye
        </span>
      )}
      {userPick?.outcome === 'eliminated' && mode !== 'predict' && (
        <span className="absolute right-2 top-1/2 flex -translate-y-1/2 items-center gap-1 rounded bg-mat-700 px-1.5 py-0.5 text-[9px] font-bold uppercase text-ink-500">
          <Ban size={9} /> Elim
        </span>
      )}
    </div>
  )
}

function Slot({ comp, slot, match, mode, interactive, picked, officialWinner, userPick, onPick, rounded }) {
  // winner_competitor_id comes back as 0 (not null) until a result is entered
  const isWinnerOfficial = !!officialWinner && comp?.id === officialWinner
  const isLoserOfficial = !!officialWinner && comp?.id != null && comp?.id !== officialWinner
  const outcome = userPick?.outcome
  const showOutcome = (mode === 'results' || mode === 'readonly') && userPick && comp && userPick.wrestler_id === comp.id

  const content = (
    <>
      {/* seed chip */}
      <span className={cn(
        'flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded font-mono text-[10px] font-bold',
        comp ? 'bg-mat-700 text-gold-400' : 'bg-mat-800 text-ink-600'
      )}>
        {comp?.seed ?? '–'}
      </span>
      <span className="min-w-0 flex-1 leading-tight">
        {comp ? (
          <>
            <span className={cn(
              'block truncate text-[12.5px] font-semibold',
              isWinnerOfficial && 'text-pin-300',
              isLoserOfficial && 'text-ink-500 line-through decoration-blood-500/60',
              picked && 'text-gold-300',
              !picked && !isWinnerOfficial && !isLoserOfficial && 'text-ink-100'
            )}>
              {comp.name}
            </span>
            <span className="block truncate text-[10px] font-medium text-ink-500">
              {comp.school}{comp.record ? ` · ${comp.record}` : ''}
            </span>
          </>
        ) : (
          <span className="block truncate text-[11px] font-medium italic text-ink-600">
            {match[`${slot}_fallback`] || 'TBD'}
          </span>
        )}
      </span>
      {/* state icons */}
      {picked && mode === 'predict' && (
        <motion.span initial={{ scale: 0 }} animate={{ scale: 1 }} className="flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-gold-500 text-mat-950">
          <Check size={11} strokeWidth={3.5} />
        </motion.span>
      )}
      {isWinnerOfficial && <Check size={14} strokeWidth={3.5} className="shrink-0 text-pin-400" />}
      {showOutcome && outcome === 'correct' && <span className="shrink-0 rounded bg-pin-500/15 px-1 font-mono text-[9px] font-bold text-pin-400">+{userPick.points_earned}</span>}
      {showOutcome && outcome === 'incorrect' && <X size={13} strokeWidth={3.5} className="shrink-0 text-blood-400" />}
      {match.pick_percentage && comp && (
        <span className="shrink-0 font-mono text-[9px] font-bold text-ink-500">
          {match.pick_percentage[slot] ?? 0}%
        </span>
      )}
    </>
  )

  const cls = cn(
    'flex w-full items-center gap-2 px-2 py-0',
    rounded === 'top' ? 'h-[38px] rounded-t-lg' : 'h-[38px] rounded-b-lg',
    picked && 'bg-gold-500/10',
    interactive && 'cursor-pointer hover:bg-gold-500/8 active:bg-gold-500/15',
  )

  if (interactive) {
    return (
      <button
        type="button"
        className={cls}
        onClick={() => onPick?.(match, picked ? null : comp.id)}
        aria-label={`${picked ? 'Clear pick' : 'Pick'} ${comp.name}${comp.seed ? `, seed ${comp.seed}` : ''}, ${match.round_label} match ${match.match_number}`}
        aria-pressed={picked}
      >
        {content}
      </button>
    )
  }
  return <div className={cls}>{content}</div>
}

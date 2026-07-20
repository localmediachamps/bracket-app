import React from 'react'
import { Sparkles } from 'lucide-react'
import { Button, Card } from '../ui'

/**
 * BestScenarioCard — surfaces the recommender's suggested pick'em roster,
 * built from the user's own championship-bracket predictions (not the
 * official seed favorite). Explains the reasoning in plain terms rather than
 * just dropping a black-box button: value picks are wrestlers predicted to
 * far outperform their seed-based cost.
 */
export default function BestScenarioCard({ bestScenario, hasBracketPicks, budget, onApply, disabled }) {
  if (!hasBracketPicks) {
    return (
      <Card className="space-y-2 border-gold-500/30 bg-gold-500/[0.04] p-4">
        <div className="flex items-center gap-2">
          <Sparkles size={15} className="text-gold-400" />
          <span className="font-display text-sm uppercase tracking-wide text-ink-100">Best Scenario</span>
        </div>
        <p className="text-xs text-ink-500">
          Finish your championship bracket predictions for this tournament first — the recommender builds your roster
          from how you think the bracket falls, not just seeding.
        </p>
      </Card>
    )
  }

  if (!bestScenario) {
    return (
      <Card className="space-y-2 p-4">
        <div className="flex items-center gap-2">
          <Sparkles size={15} className="text-gold-400" />
          <span className="font-display text-sm uppercase tracking-wide text-ink-100">Best Scenario</span>
        </div>
        <p className="text-xs text-ink-500">Crunching your bracket predictions…</p>
      </Card>
    )
  }

  return (
    <Card className="space-y-3 border-gold-500/30 bg-gold-500/[0.04] p-4">
      <div className="flex items-center gap-2">
        <Sparkles size={15} className="text-gold-400" />
        <span className="font-display text-sm uppercase tracking-wide text-ink-100">Best Scenario</span>
      </div>
      <p className="text-xs text-ink-500">
        The highest-projected roster your budget can afford, based on your own bracket predictions — value picks are
        wrestlers predicted to place much better than their seed-based cost would suggest. Applying it fills every
        weight class; you can still swap anyone before submitting.
      </p>
      <div className="flex items-center justify-between rounded-lg border border-mat-700 bg-mat-850 px-3 py-2">
        <span className="text-[10px] font-bold uppercase tracking-wider text-ink-500">Projected points</span>
        <span className="font-mono text-sm font-bold text-gold-400">{bestScenario.totalPoints}</span>
      </div>
      <div className="flex items-center justify-between rounded-lg border border-mat-700 bg-mat-850 px-3 py-2">
        <span className="text-[10px] font-bold uppercase tracking-wider text-ink-500">Cost</span>
        <span className="font-mono text-sm font-bold text-ink-200">
          {bestScenario.totalCost} / {budget}
        </span>
      </div>
      <Button size="sm" className="w-full" onClick={onApply} disabled={disabled}>
        <Sparkles size={14} /> Apply Best Scenario
      </Button>
    </Card>
  )
}

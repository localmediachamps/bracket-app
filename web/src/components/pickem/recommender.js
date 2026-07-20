import { resolvePicks } from '../bracket/bracketMath'

const PLACEMENT_SPECS = [
  { code: 'champ_finals', win: 1, lose: 2 },
  { code: 'place_3', win: 3, lose: 4 },
  { code: 'place_5', win: 5, lose: 6 },
  { code: 'place_7', win: 7, lose: 8 },
]

/**
 * Projects a fantasy point total per wrestler for one weight class, based on
 * the user's OWN championship-bracket predictions (not the official seed
 * favorite) — mirrors how a player manually value-hunts: predict how the
 * bracket falls, then see who over-delivers relative to their (seed-based)
 * salary cost. Win points accrue for every match a wrestler is predicted to
 * win (per section); placement points come from where they're predicted to
 * finish (1st-8th, via the same champ_finals/place_3/5/7 resolution
 * PlacementTable uses). A wrestler who isn't predicted to win anything
 * projects to 0 — that's correct, not a bug.
 *
 * Returns Map(wrestlerId → { wins, placement, points }).
 */
export function projectWrestlerPoints(matches, picksMap, competitorsById, scoring) {
  const winPoints = scoring?.win_points ?? {}
  const placementPoints = scoring?.placement_points ?? {}
  const projections = new Map()

  const bump = (id, points) => {
    if (id == null) return
    const cur = projections.get(id) ?? { wins: 0, placement: null, points: 0 }
    cur.points += points
    projections.set(id, cur)
  }

  if (!matches?.length) return projections

  const resolution = resolvePicks(matches, picksMap ?? new Map(), competitorsById ?? new Map())

  for (const m of matches) {
    const winnerId = resolution.validPicks.get(m.id)
    if (winnerId == null) continue
    const pts = winPoints[m.section]
    if (pts) {
      const cur = projections.get(winnerId) ?? { wins: 0, placement: null, points: 0 }
      cur.wins += 1
      projections.set(winnerId, cur)
      bump(winnerId, pts)
    }
  }

  const byCode = new Map(matches.map((m) => [m.round_code, m]))
  for (const spec of PLACEMENT_SPECS) {
    const m = byCode.get(spec.code)
    if (!m) continue
    const r = resolution.resolved.get(m.id)
    const winnerId = resolution.validPicks.get(m.id) ?? null
    if (winnerId == null || !r) continue
    const loser = [r.top, r.bottom].find((c) => c && c.id !== winnerId) ?? null

    const winCur = projections.get(winnerId) ?? { wins: 0, placement: null, points: 0 }
    winCur.placement = spec.win
    projections.set(winnerId, winCur)
    bump(winnerId, placementPoints[spec.win] ?? 0)

    if (loser) {
      const loseCur = projections.get(loser.id) ?? { wins: 0, placement: null, points: 0 }
      loseCur.placement = spec.lose
      projections.set(loser.id, loseCur)
      bump(loser.id, placementPoints[spec.lose] ?? 0)
    }
  }

  return projections
}

/**
 * Multiple-choice knapsack: exactly one option per group (weight class),
 * total cost ≤ budget, maximize total points. Exact DP, not greedy — problem
 * size here (~10-14 groups × ~33 options × budget ≤ ~1000) is trivial, and
 * greedy value/cost sorting can miss better combinations knapsack DP
 * guarantees to find.
 *
 * groups: [{ key, options: [{ id, cost, points }] }]
 * Returns { selections: Map(groupKey → optionId), totalPoints, totalCost }.
 */
export function solveBestScenario(groups, budget) {
  const B = Math.max(0, Math.floor(budget ?? 0))
  let dp = new Array(B + 1).fill(-Infinity)
  dp[0] = 0
  const stepsChoice = []

  for (const group of groups) {
    const opts = group.options?.length ? group.options : [{ id: null, cost: 0, points: 0 }]
    const nextDp = new Array(B + 1).fill(-Infinity)
    const choiceForBudget = new Array(B + 1).fill(null)
    for (let b = 0; b <= B; b++) {
      if (dp[b] === -Infinity) continue
      for (const opt of opts) {
        const nb = b + (opt.cost ?? 0)
        if (nb > B) continue
        const val = dp[b] + (opt.points ?? 0)
        if (val > nextDp[nb]) {
          nextDp[nb] = val
          choiceForBudget[nb] = opt.id
        }
      }
    }
    dp = nextDp
    stepsChoice.push(choiceForBudget)
  }

  let bestB = 0
  for (let b = 0; b <= B; b++) if (dp[b] > dp[bestB]) bestB = b

  const selections = new Map()
  if (dp[bestB] === -Infinity) return { selections, totalPoints: 0, totalCost: 0 }

  let b = bestB
  for (let g = groups.length - 1; g >= 0; g--) {
    const chosen = stepsChoice[g][b]
    selections.set(groups[g].key, chosen)
    const opt = (groups[g].options ?? []).find((o) => o.id === chosen)
    b -= opt?.cost ?? 0
  }

  return { selections, totalPoints: dp[bestB], totalCost: bestB }
}

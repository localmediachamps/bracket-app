import React, { useMemo } from 'react'
import { Trophy } from 'lucide-react'
import { cn } from '../../lib/utils'

/**
 * PlacementTable — ranked 1st-through-8th list instead of a bracket canvas.
 * 1st/2nd come from the championship final (not part of the "placement"
 * section itself); 3rd-8th come from the place_3/place_5/place_7 matches,
 * winner taking the higher spot. Needs the FULL match set (not just the
 * placement-section subset) to resolve the championship final too.
 */
export default function PlacementTable({ matches, resolution, picks, mode }) {
  const rows = useMemo(() => {
    const byCode = new Map(matches.map((m) => [m.round_code, m]))
    const specs = [
      { code: 'champ_finals', win: 1, lose: 2 },
      { code: 'place_3', win: 3, lose: 4 },
      { code: 'place_5', win: 5, lose: 6 },
      { code: 'place_7', win: 7, lose: 8 },
    ]
    const out = []
    for (const spec of specs) {
      const m = byCode.get(spec.code)
      if (!m) continue

      let top, bottom, winnerId
      if (mode === 'predict') {
        const r = resolution?.resolved.get(m.id)
        top = r?.top ?? null
        bottom = r?.bottom ?? null
        winnerId = picks?.get(m.id) ?? null
      } else {
        top = m.top?.competitor ?? null
        bottom = m.bottom?.competitor ?? null
        // winner_competitor_id comes back as 0 (not null) until a result exists
        winnerId = m.winner_competitor_id > 0 ? m.winner_competitor_id : null
      }

      const winner = winnerId != null ? [top, bottom].find((c) => c?.id === winnerId) ?? null : null
      const loser = winnerId != null ? [top, bottom].find((c) => c && c.id !== winnerId) ?? null : null
      out.push({ place: spec.win, competitor: winner })
      out.push({ place: spec.lose, competitor: loser })
    }
    return out.sort((a, b) => a.place - b.place)
  }, [matches, resolution, picks, mode])

  if (!rows.length) {
    return (
      <div className="flex h-48 items-center justify-center rounded-xl border border-dashed border-mat-600 text-sm text-ink-500">
        No placement matches for this weight.
      </div>
    )
  }

  return (
    <div className="overflow-hidden rounded-xl border border-mat-700 bg-mat-900/60">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-mat-700 bg-mat-850/60 text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
            <th className="px-4 py-3 w-20">Place</th>
            <th className="px-4 py-3">Wrestler</th>
            <th className="px-4 py-3">School</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.place} className="border-b border-mat-800 last:border-0">
              <td className="px-4 py-3">
                <span
                  className={cn(
                    'inline-flex h-7 w-7 items-center justify-center rounded-full font-mono text-xs font-bold',
                    r.place <= 3 ? 'bg-gold-500/15 text-gold-400' : 'bg-mat-800 text-ink-400'
                  )}
                >
                  {r.place === 1 ? <Trophy size={13} /> : r.place}
                </span>
              </td>
              <td className="px-4 py-3">
                {r.competitor ? (
                  <span className="font-semibold text-ink-100">{r.competitor.name}</span>
                ) : (
                  <span className="italic text-ink-600">TBD</span>
                )}
              </td>
              <td className="px-4 py-3 text-ink-500">{r.competitor?.school ?? '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

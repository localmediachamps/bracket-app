import React from 'react'
import { Plus, Trash2 } from 'lucide-react'
import { cn } from '../../lib/utils'
import { nextKey, rowIssueLevels } from './adminUtils'

const cellInput =
  'w-full rounded-lg border border-mat-600 bg-mat-800 px-2 h-9 text-sm text-ink-100 placeholder:text-ink-600 transition-colors hover:border-mat-500 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25'

/**
 * Editable competitor table.
 * props:
 *  rows           [{key, seed, name, school, record, withdrawn?}]
 *  onChange(rows)
 *  issues         validation issues from validateCompetitors (tints rows)
 *  showWithdrawn  render withdrawn toggle column
 *  disabled       lock all editing
 */
export default function CompetitorTable({ rows, onChange, issues = [], showWithdrawn = false, disabled = false }) {
  const levels = rowIssueLevels(issues)

  const update = (key, field, value) => {
    onChange(rows.map((r) => (r.key === key ? { ...r, [field]: value } : r)))
  }
  const remove = (key) => onChange(rows.filter((r) => r.key !== key))
  const add = () => {
    const maxSeed = rows.reduce((m, r) => Math.max(m, Number(r.seed) || 0), 0)
    onChange([...rows, { key: nextKey(), seed: String(maxSeed + 1), name: '', school: '', record: '' }])
  }

  return (
    <div>
      <div className="overflow-x-auto -mx-1 px-1">
        <table className="w-full min-w-[560px] border-separate border-spacing-y-1.5">
          <thead>
            <tr className="text-left text-[10px] font-bold uppercase tracking-[0.12em] text-ink-500">
              <th className="w-16 px-1">Seed</th>
              <th className="px-1">Name</th>
              <th className="px-1">School</th>
              <th className="w-24 px-1">Record</th>
              {showWithdrawn && <th className="w-20 px-1 text-center">Wdrawn</th>}
              {!disabled && <th className="w-10 px-1" aria-label="actions" />}
            </tr>
          </thead>
          <tbody>
            {rows.map((r, i) => {
              const level = levels.get(i)
              return (
                <tr
                  key={r.key}
                  className={cn(
                    'rounded-lg',
                    level === 'error' && '[&>td]:bg-blood-500/8',
                    level === 'warn' && '[&>td]:bg-gold-500/6'
                  )}
                >
                  <td className="rounded-l-lg px-1 py-0.5">
                    <input
                      type="number"
                      min={1}
                      value={r.seed}
                      disabled={disabled}
                      onChange={(e) => update(r.key, 'seed', e.target.value)}
                      aria-label={`Seed for row ${i + 1}`}
                      className={cn(cellInput, 'font-mono text-center', level === 'error' && 'border-blood-500/60', level === 'warn' && 'border-gold-500/50')}
                    />
                  </td>
                  <td className="px-1 py-0.5">
                    <input
                      value={r.name}
                      disabled={disabled}
                      onChange={(e) => update(r.key, 'name', e.target.value)}
                      placeholder="First Last"
                      aria-label={`Name for row ${i + 1}`}
                      className={cn(cellInput, level === 'error' && !r.name?.trim() && 'border-blood-500/60')}
                    />
                  </td>
                  <td className="px-1 py-0.5">
                    <input
                      value={r.school}
                      disabled={disabled}
                      onChange={(e) => update(r.key, 'school', e.target.value)}
                      placeholder="School"
                      aria-label={`School for row ${i + 1}`}
                      className={cn(cellInput, level === 'warn' && 'border-gold-500/50')}
                    />
                  </td>
                  <td className="px-1 py-0.5">
                    <input
                      value={r.record ?? ''}
                      disabled={disabled}
                      onChange={(e) => update(r.key, 'record', e.target.value)}
                      placeholder="24-0"
                      aria-label={`Record for row ${i + 1}`}
                      className={cn(cellInput, 'font-mono')}
                    />
                  </td>
                  {showWithdrawn && (
                    <td className="px-1 py-0.5 text-center">
                      <button
                        type="button"
                        role="switch"
                        aria-checked={!!r.withdrawn}
                        aria-label={`Withdrawn toggle for ${r.name || `row ${i + 1}`}`}
                        disabled={disabled}
                        onClick={() => update(r.key, 'withdrawn', !r.withdrawn)}
                        className={cn(
                          'relative inline-flex h-5 w-9 items-center rounded-full transition-colors disabled:opacity-50',
                          r.withdrawn ? 'bg-blood-500' : 'bg-mat-600'
                        )}
                      >
                        <span className={cn('absolute h-4 w-4 rounded-full bg-white transition-transform', r.withdrawn ? 'translate-x-[18px]' : 'translate-x-0.5')} />
                      </button>
                    </td>
                  )}
                  {!disabled && (
                    <td className="rounded-r-lg px-1 py-0.5 text-center">
                      <button
                        type="button"
                        onClick={() => remove(r.key)}
                        aria-label={`Remove ${r.name || `row ${i + 1}`}`}
                        className="rounded-md p-1.5 text-ink-600 transition-colors hover:bg-blood-500/15 hover:text-blood-400"
                      >
                        <Trash2 size={14} />
                      </button>
                    </td>
                  )}
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
      {!disabled && (
        <button
          type="button"
          onClick={add}
          className="mt-1 inline-flex items-center gap-1.5 rounded-lg border border-dashed border-mat-600 px-3 py-2 text-xs font-bold text-ink-400 transition-colors hover:border-gold-500/50 hover:text-gold-400"
        >
          <Plus size={13} /> Add wrestler
        </button>
      )}
    </div>
  )
}

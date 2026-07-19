import React, { useMemo, useState } from 'react'
import { ClipboardPaste, AlertTriangle, AlertCircle } from 'lucide-react'
import { Button, Textarea } from '../ui'
import { cn } from '../../lib/utils'
import { parseCompetitorLines, validateCompetitors } from './adminUtils'

/**
 * Quick-paste competitor list.
 * One per line: `seed name school [record]` — e.g. `1 Spencer Lee Penn State 24-0`.
 * props:
 *  onApply(rows, {append})  — parsed rows (with keys)
 *  appendable               — show "Append" button alongside "Replace"
 */
export default function PasteCompetitors({ onApply, appendable = false }) {
  const [text, setText] = useState('')
  const parsed = useMemo(() => parseCompetitorLines(text), [text])
  const issues = useMemo(() => validateCompetitors(parsed), [parsed])
  const errors = issues.filter((i) => i.level === 'error')
  const warns = issues.filter((i) => i.level === 'warn')

  const apply = (append) => {
    if (!parsed.length) return
    onApply(parsed, { append })
    setText('')
  }

  return (
    <div className="space-y-3">
      <Textarea
        rows={8}
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder={'1 Spencer Lee Penn State 24-0\n2 Drake Ayala Iowa 21-2\n3 Troy Spratley Oklahoma State\n…'}
        className="font-mono text-xs leading-relaxed"
        aria-label="Paste competitor list"
      />
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap items-center gap-2 text-xs">
          {text.trim() ? (
            <>
              <span className="font-mono font-bold text-ink-300">{parsed.length} parsed</span>
              {errors.length > 0 && (
                <span className="inline-flex items-center gap-1 font-semibold text-blood-400">
                  <AlertCircle size={12} /> {errors.length} error{errors.length === 1 ? '' : 's'}
                </span>
              )}
              {warns.length > 0 && (
                <span className="inline-flex items-center gap-1 font-semibold text-gold-400">
                  <AlertTriangle size={12} /> {warns.length} warning{warns.length === 1 ? '' : 's'}
                </span>
              )}
            </>
          ) : (
            <span className="text-ink-600">One wrestler per line — seed, name, school, optional record</span>
          )}
        </div>
        <div className="flex gap-2">
          {appendable && (
            <Button variant="secondary" size="sm" disabled={!parsed.length} onClick={() => apply(true)}>
              Append
            </Button>
          )}
          <Button variant="primary" size="sm" disabled={!parsed.length} onClick={() => apply(false)}>
            <ClipboardPaste size={14} /> {appendable ? 'Replace list' : 'Load list'}
          </Button>
        </div>
      </div>
      {issues.length > 0 && (
        <ul className="max-h-32 space-y-1 overflow-y-auto rounded-lg border border-mat-700 bg-mat-900/60 p-3 text-xs">
          {issues.slice(0, 20).map((it, i) => (
            <li key={i} className={cn('flex items-center gap-1.5', it.level === 'error' ? 'text-blood-400' : 'text-gold-400')}>
              {it.level === 'error' ? <AlertCircle size={12} /> : <AlertTriangle size={12} />}
              {it.message}
            </li>
          ))}
          {issues.length > 20 && <li className="text-ink-500">…and {issues.length - 20} more</li>}
        </ul>
      )}
    </div>
  )
}

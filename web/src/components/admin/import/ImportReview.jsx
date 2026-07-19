import React, { useMemo, useState } from 'react'
import { AlertCircle, AlertTriangle, Check, Plus, Trash2, FileText, Info } from 'lucide-react'
import { Button, Card, Input, Select } from '../../ui'
import { cn } from '../../../lib/utils'
import CompetitorTable from '../CompetitorTable'
import { TEMPLATES, nextKey, normalizeDocument, validateCompetitors } from '../adminUtils'

/**
 * Import review — edit extracted tournament meta + per-weight competitor tables
 * before confirming. Brackets are generated server-side on confirm.
 *
 * props:
 *  doc          raw uploaded_document payload (extraction_result + issues)
 *  confirming   bool (disable actions while confirm mutation runs)
 *  confirmLabel button text (default "Confirm & build brackets")
 *  onConfirm(payload)  payload = {name, year, location, start_date, weights:[{weight, template, competitors}]}
 *  onDiscard    optional cancel handler
 */
export default function ImportReview({ doc, confirming, confirmLabel = 'Confirm & build brackets', onConfirm, onDiscard }) {
  const normalized = useMemo(() => normalizeDocument(doc), [doc])
  const [meta, setMeta] = useState(normalized.meta)
  const [weights, setWeights] = useState(normalized.weights)

  const sorted = useMemo(
    () => [...weights].sort((a, b) => (Number(a.weight) || 9999) - (Number(b.weight) || 9999)),
    [weights]
  )

  const issuesByWeight = useMemo(() => {
    const map = new Map()
    for (const w of weights) map.set(w.key, validateCompetitors(w.competitors))
    return map
  }, [weights])

  const allIssues = useMemo(() => [...issuesByWeight.values()].flat(), [issuesByWeight])
  const errorCount = allIssues.filter((i) => i.level === 'error').length
  const warnCount = allIssues.filter((i) => i.level === 'warn').length
  const serverIssues = normalized.serverIssues ?? []

  const updateWeight = (key, patch) => setWeights((ws) => ws.map((w) => (w.key === key ? { ...w, ...patch } : w)))
  const removeWeight = (key) => setWeights((ws) => ws.filter((w) => w.key !== key))
  const addWeight = () => setWeights((ws) => [...ws, { key: nextKey(), weight: '', template: 'ncaa_33', competitors: [] }])

  const confirm = () => {
    onConfirm({
      name: meta.name?.trim() || undefined,
      year: meta.year ? Number(meta.year) : undefined,
      location: meta.location?.trim() || undefined,
      start_date: meta.date || undefined,
      weights: sorted.map((w) => ({
        weight: Number(w.weight),
        template: w.template,
        competitors: w.competitors.map((c) => ({
          seed: Number(c.seed),
          name: String(c.name || '').trim(),
          school: String(c.school || '').trim(),
          record: String(c.record || '').trim() || undefined,
        })),
      })),
    })
  }

  return (
    <div className="space-y-5">
      {/* meta */}
      <Card className="p-5">
        <div className="mb-4 flex items-center gap-2">
          <FileText size={16} className="text-gold-500" />
          <h3 className="font-display text-sm uppercase tracking-wide text-ink-100">Extracted tournament</h3>
          {normalized.fileName && <span className="ml-auto truncate text-xs text-ink-600">{normalized.fileName}</span>}
        </div>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Input label="Name" value={meta.name ?? ''} onChange={(e) => setMeta((m) => ({ ...m, name: e.target.value }))} placeholder="NCAA Division I Championships" />
          <Input label="Year" type="number" value={meta.year ?? ''} onChange={(e) => setMeta((m) => ({ ...m, year: e.target.value }))} placeholder="2026" />
          <Input label="Location" value={meta.location ?? ''} onChange={(e) => setMeta((m) => ({ ...m, location: e.target.value }))} placeholder="Cleveland, OH" />
          <Input label="Start date" type="date" value={meta.date ?? ''} onChange={(e) => setMeta((m) => ({ ...m, date: e.target.value }))} />
        </div>
      </Card>

      {/* server-reported issues */}
      {serverIssues.length > 0 && (
        <Card className="border-gold-500/30 p-4">
          <p className="mb-2 flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-gold-400">
            <AlertTriangle size={13} /> Parser flagged {serverIssues.length} issue{serverIssues.length === 1 ? '' : 's'}
          </p>
          <ul className="max-h-36 space-y-1 overflow-y-auto text-xs text-ink-300">
            {serverIssues.map((it, i) => (
              <li key={i} className="flex items-start gap-1.5">
                <span className="mt-0.5 h-1 w-1 shrink-0 rounded-full bg-gold-400" />
                {typeof it === 'string' ? it : it.message ?? JSON.stringify(it)}
              </li>
            ))}
          </ul>
        </Card>
      )}

      {/* weights */}
      {sorted.map((w) => {
        const issues = issuesByWeight.get(w.key) ?? []
        const errs = issues.filter((i) => i.level === 'error').length
        const warns = issues.filter((i) => i.level === 'warn').length
        return (
          <Card key={w.key} className={cn('p-5', errs > 0 && 'border-blood-500/40')}>
            <div className="mb-4 flex flex-wrap items-center gap-3">
              <div className="flex items-center gap-2">
                <input
                  type="number"
                  value={w.weight}
                  onChange={(e) => updateWeight(w.key, { weight: e.target.value })}
                  aria-label="Weight class"
                  className="h-10 w-24 rounded-xl border border-mat-600 bg-mat-800 px-3 text-center font-mono text-sm font-bold text-gold-400 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25"
                />
                <span className="text-xs font-bold uppercase tracking-wider text-ink-500">lbs</span>
              </div>
              <div className="w-56">
                <Select value={w.template} onChange={(e) => updateWeight(w.key, { template: e.target.value })} aria-label="Bracket template" className="h-10">
                  {TEMPLATES.map((t) => (
                    <option key={t.value} value={t.value}>{t.label}</option>
                  ))}
                </Select>
              </div>
              <span className="text-xs text-ink-500">{w.competitors.length} wrestlers</span>
              {errs > 0 && (
                <span className="inline-flex items-center gap-1 text-xs font-semibold text-blood-400"><AlertCircle size={12} /> {errs}</span>
              )}
              {warns > 0 && (
                <span className="inline-flex items-center gap-1 text-xs font-semibold text-gold-400"><AlertTriangle size={12} /> {warns}</span>
              )}
              <button
                type="button"
                onClick={() => removeWeight(w.key)}
                className="ml-auto rounded-lg p-2 text-ink-600 transition-colors hover:bg-blood-500/15 hover:text-blood-400"
                aria-label={`Remove weight ${w.weight}`}
              >
                <Trash2 size={15} />
              </button>
            </div>

            {issues.length > 0 && (
              <ul className="mb-3 flex max-h-24 flex-col gap-1 overflow-y-auto rounded-lg border border-mat-700 bg-mat-900/60 p-3 text-xs">
                {issues.map((it, i) => (
                  <li key={i} className={cn('flex items-center gap-1.5', it.level === 'error' ? 'text-blood-400' : 'text-gold-400')}>
                    {it.level === 'error' ? <AlertCircle size={12} /> : <AlertTriangle size={12} />} {it.message}
                  </li>
                ))}
              </ul>
            )}

            <CompetitorTable
              rows={w.competitors}
              issues={issues}
              onChange={(rows) => updateWeight(w.key, { competitors: rows })}
              disabled={confirming}
            />
            <p className="mt-3 flex items-center gap-1.5 text-[11px] text-ink-600">
              <Info size={11} /> Bracket will be generated from this list on confirm.
            </p>
          </Card>
        )
      })}

      <button
        type="button"
        onClick={addWeight}
        className="flex w-full items-center justify-center gap-2 rounded-xl border border-dashed border-mat-600 py-3 text-sm font-bold text-ink-400 transition-colors hover:border-gold-500/50 hover:text-gold-400"
      >
        <Plus size={15} /> Add missing weight class
      </button>

      {/* confirm bar */}
      <div className="sticky bottom-3 z-10 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-mat-600 bg-mat-850/95 p-4 shadow-card backdrop-blur">
        <div className="text-xs">
          {errorCount > 0 ? (
            <span className="flex items-center gap-1.5 font-semibold text-blood-400">
              <AlertCircle size={13} /> Resolve {errorCount} error{errorCount === 1 ? '' : 's'} to confirm
            </span>
          ) : warnCount > 0 ? (
            <span className="flex items-center gap-1.5 font-semibold text-gold-400">
              <AlertTriangle size={13} /> {warnCount} warning{warnCount === 1 ? '' : 's'} — you can still confirm
            </span>
          ) : (
            <span className="flex items-center gap-1.5 font-semibold text-pin-400">
              <Check size={13} /> Looks clean — {sorted.length} weights ready
            </span>
          )}
        </div>
        <div className="flex gap-2">
          {onDiscard && (
            <Button variant="ghost" onClick={onDiscard} disabled={confirming}>Back</Button>
          )}
          <Button variant="primary" onClick={confirm} loading={confirming} disabled={errorCount > 0 || sorted.length === 0}>
            <Check size={15} /> {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  )
}

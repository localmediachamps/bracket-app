import React, { useState } from 'react'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { ChevronDown, ChevronLeft, ChevronRight, Filter, ScrollText } from 'lucide-react'
import { api } from '../../lib/api'
import { Badge, Button, Card, EmptyState, Input, Select, Skeleton } from '../../components/ui'
import { cn, formatDateTime } from '../../lib/utils'
import { ErrorState, PageHeader } from '../../components/admin/AdminCommon'
import { actorLabel, AUDIT_ENTITY_TYPES, auditActionColor, changedKeys, timeAgo } from '../../components/admin/adminUtils'

const PER = 25

export default function AdminAudit() {
  const [entityType, setEntityType] = useState('')
  const [entityId, setEntityId] = useState('')
  const [page, setPage] = useState(1)
  const [expanded, setExpanded] = useState(null)

  const q = useQuery({
    queryKey: ['admin', 'audit', entityType, entityId, page],
    queryFn: () =>
      api.adminAuditLogs({
        entity_type: entityType || undefined,
        entity_id: entityId || undefined,
        page,
        per: PER,
      }),
    placeholderData: keepPreviousData,
  })

  const items = Array.isArray(q.data) ? q.data : q.data?.items ?? []
  const total = q.data?.total ?? (Array.isArray(q.data) ? q.data.length : items.length)
  const pages = Math.max(1, Math.ceil(total / PER))

  const applyFilter = (setter) => (e) => {
    setter(e.target.value)
    setPage(1)
  }

  return (
    <div>
      <PageHeader title="Audit Log" sub="Every admin mutation — who, what, when, and before → after." />

      {/* filter bar */}
      <Card className="mb-4 flex flex-wrap items-end gap-3 p-4">
        <div className="w-52">
          <Select label="Entity type" value={entityType} onChange={applyFilter(setEntityType)}>
            <option value="">All types</option>
            {AUDIT_ENTITY_TYPES.map((t) => (
              <option key={t} value={t}>{t}</option>
            ))}
          </Select>
        </div>
        <div className="w-40">
          <Input label="Entity ID" type="number" value={entityId} onChange={applyFilter(setEntityId)} placeholder="any" />
        </div>
        <div className="ml-auto flex items-center gap-1.5 text-xs text-ink-500">
          <Filter size={12} />
          {total} entr{total === 1 ? 'y' : 'ies'}
        </div>
      </Card>

      {q.isLoading ? (
        <div className="space-y-2">
          {[...Array(6)].map((_, i) => <Skeleton key={i} className="h-12" />)}
        </div>
      ) : q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} title="Couldn't load audit log" />
      ) : items.length === 0 ? (
        <EmptyState icon={<ScrollText size={24} />} title="Nothing logged" body="Admin actions will appear here as they happen." />
      ) : (
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-sm">
              <thead>
                <tr className="border-b border-mat-700 text-left text-[10px] font-bold uppercase tracking-[0.12em] text-ink-500">
                  <th className="px-4 py-3">Time</th>
                  <th className="px-4 py-3">Actor</th>
                  <th className="px-4 py-3">Action</th>
                  <th className="px-4 py-3">Entity</th>
                  <th className="w-10 px-2 py-3" aria-label="expand" />
                </tr>
              </thead>
              <tbody>
                {items.map((row) => {
                  const open = expanded === row.id
                  const hasDiff = row.previous_value != null || row.new_value != null
                  return (
                    <React.Fragment key={row.id}>
                      <tr
                        className={cn('border-b border-mat-700/60 transition-colors hover:bg-mat-800/40', open && 'bg-mat-800/40', hasDiff && 'cursor-pointer')}
                        onClick={() => hasDiff && setExpanded(open ? null : row.id)}
                      >
                        <td className="whitespace-nowrap px-4 py-3 text-xs text-ink-400" title={formatDateTime(row.created_at)}>
                          {timeAgo(row.created_at)}
                        </td>
                        <td className="px-4 py-3 font-semibold text-ink-200">{actorLabel(row)}</td>
                        <td className="px-4 py-3">
                          <Badge color={auditActionColor(row.action)}>{row.action}</Badge>
                        </td>
                        <td className="px-4 py-3 font-mono text-xs text-ink-300">
                          {row.entity_type}{row.entity_id ? ` #${row.entity_id}` : ''}
                        </td>
                        <td className="px-2 py-3 text-right">
                          {hasDiff && (
                            <ChevronDown size={15} className={cn('inline text-ink-500 transition-transform', open && 'rotate-180 text-gold-400')} />
                          )}
                        </td>
                      </tr>
                      {open && hasDiff && (
                        <tr className="border-b border-mat-700/60 bg-mat-900/40">
                          <td colSpan={5} className="px-4 py-4">
                            <DiffView prev={row.previous_value} next={row.new_value} />
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  )
                })}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {/* pagination */}
      {pages > 1 && (
        <div className="mt-4 flex items-center justify-center gap-3">
          <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
            <ChevronLeft size={14} /> Prev
          </Button>
          <span className="font-mono text-xs text-ink-400">
            Page {page} of {pages}
          </span>
          <Button variant="secondary" size="sm" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>
            Next <ChevronRight size={14} />
          </Button>
        </div>
      )}
    </div>
  )
}

/* ── prev vs new pretty diff ────────────────────────── */
function DiffView({ prev, next }) {
  const changed = changedKeys(prev ?? {}, next ?? {})
  const keys = [...new Set([...Object.keys(prev ?? {}), ...Object.keys(next ?? {})])].sort()

  if (keys.length === 0) {
    return <p className="text-xs text-ink-500">No field-level diff recorded.</p>
  }

  const renderValue = (obj, k, side) => {
    const present = obj && Object.prototype.hasOwnProperty.call(obj, k)
    if (!present) return <span className="italic text-ink-600">—</span>
    const v = obj[k]
    return (
      <span className={cn(changed.has(k) && (side === 'next' ? 'text-gold-300' : 'text-blood-300/90'))}>
        {typeof v === 'object' && v !== null ? JSON.stringify(v) : String(v ?? 'null')}
      </span>
    )
  }

  return (
    <div className="grid gap-3 lg:grid-cols-2">
      {[
        { title: 'Before', obj: prev ?? {}, side: 'prev' },
        { title: 'After', obj: next ?? {}, side: 'next' },
      ].map((col) => (
        <div key={col.side} className="overflow-hidden rounded-lg border border-mat-700">
          <p className={cn(
            'border-b border-mat-700 px-3 py-1.5 text-[10px] font-bold uppercase tracking-wider',
            col.side === 'next' ? 'text-gold-400' : 'text-ink-500'
          )}>
            {col.title}
          </p>
          <dl className="max-h-72 overflow-y-auto p-3 font-mono text-[11px] leading-relaxed">
            {keys.map((k) => (
              <div key={k} className={cn('flex gap-2 rounded px-1 py-0.5', changed.has(k) && 'bg-mat-800/70')}>
                <dt className={cn('shrink-0', changed.has(k) ? 'font-bold text-gold-400' : 'text-ink-500')}>{k}:</dt>
                <dd className="min-w-0 break-all text-ink-300">{renderValue(col.obj, k, col.side)}</dd>
              </div>
            ))}
          </dl>
        </div>
      ))}
    </div>
  )
}

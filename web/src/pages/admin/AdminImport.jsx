import React, { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { FileText, RotateCcw } from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Badge, Button, Card, Skeleton, StatusPill } from '../../components/ui'
import { formatDateTime } from '../../lib/utils'
import { ErrorState, PageHeader } from '../../components/admin/AdminCommon'
import ImportFlow from '../../components/admin/import/ImportFlow'
import ImportReview from '../../components/admin/import/ImportReview'
import { errMsg } from '../../components/admin/adminUtils'

export default function AdminImport() {
  const { id } = useParams()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [resumeDoc, setResumeDoc] = useState(null)

  const tQ = useQuery({ queryKey: ['admin', 'tournament', id], queryFn: () => api.tournament(id) })
  const tournament = tQ.data?.tournament ?? tQ.data
  const sourceDocId = tournament?.source_document_id

  const docQ = useQuery({
    queryKey: ['admin', 'document', sourceDocId],
    queryFn: () => api.adminGetDocument(sourceDocId),
    enabled: !!sourceDocId,
  })

  const confirmMut = useMutation({
    mutationFn: (payload) => api.adminConfirmDocument(resumeDoc?.id ?? sourceDocId, payload),
    onSuccess: () => {
      toast.success('Import confirmed', { body: 'Weights and brackets rebuilt from the document.' })
      qc.invalidateQueries({ queryKey: ['admin', 'tournament', id] })
      navigate(`/admin/tournaments/${id}/builder`)
    },
    onError: (e) => toast.error('Confirm failed', { body: errMsg(e) }),
  })

  const onConfirmed = () => {
    qc.invalidateQueries({ queryKey: ['admin', 'tournament', id] })
    navigate(`/admin/tournaments/${id}/builder`)
  }

  if (resumeDoc) {
    return (
      <div>
        <PageHeader title="Review previous upload" sub="This document was uploaded earlier — confirm to apply, or go back." />
        <ImportReview
          doc={resumeDoc}
          confirming={confirmMut.isPending}
          onConfirm={(payload) => confirmMut.mutate({ tournament_id: Number(id), ...payload })}
          onDiscard={() => setResumeDoc(null)}
        />
      </div>
    )
  }

  return (
    <div>
      <PageHeader
        title="PDF Import"
        sub={`${tournament?.name ?? 'Tournament'} · upload a bracket PDF, review the extraction, confirm.`}
      />

      <Card className="mb-6 p-5">
        <ImportFlow tournamentId={id} onConfirmed={onConfirmed} />
      </Card>

      {/* previously uploaded document */}
      {sourceDocId && (
        <Card className="p-5">
          <h2 className="mb-3 flex items-center gap-2 font-display text-sm uppercase tracking-wide text-ink-100">
            <FileText size={15} className="text-gold-500" /> Source document
          </h2>
          {docQ.isLoading ? (
            <Skeleton className="h-14" />
          ) : docQ.isError ? (
            <ErrorState error={docQ.error} onRetry={() => docQ.refetch()} title="Couldn't load document" />
          ) : (
            <div className="flex flex-wrap items-center gap-3">
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-ink-100">{docQ.data?.file_name ?? `Document #${sourceDocId}`}</p>
                <p className="text-xs text-ink-500">
                  Uploaded {docQ.data?.created_at ? formatDateTime(docQ.data.created_at) : '—'}
                  {docQ.data?.file_size ? ` · ${(docQ.data.file_size / 1048576).toFixed(1)} MB` : ''}
                </p>
              </div>
              <StatusPill status={docQ.data?.processing_status} />
              {docQ.data?.processing_status === 'needs_review' && (
                <Button variant="secondary" size="sm" onClick={() => setResumeDoc(docQ.data)}>
                  <RotateCcw size={14} /> Open review
                </Button>
              )}
              {docQ.data?.processing_status === 'confirmed' && (
                <Badge color="pin">Applied to this tournament</Badge>
              )}
            </div>
          )}
        </Card>
      )}
    </div>
  )
}

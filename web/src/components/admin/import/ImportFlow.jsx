import React, { useEffect, useRef, useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import { CheckCircle2, Loader2, RotateCcw } from 'lucide-react'
import { api } from '../../../lib/api'
import { toast } from '../../../lib/store'
import { Button, Card } from '../../ui'
import PdfDropzone from './PdfDropzone'
import ImportReview from './ImportReview'
import { errMsg } from '../adminUtils'

const TERMINAL = ['needs_review', 'confirmed', 'failed']

/**
 * End-to-end PDF import flow: dropzone → upload → poll document → review → confirm.
 * props:
 *  tournamentId   existing tournament to attach
 *  onConfirmed()  called after a successful confirm
 *  onCancel       optional — renders a back button on the review step
 */
export default function ImportFlow({ tournamentId, onConfirmed, onCancel }) {
  const [phase, setPhase] = useState('idle') // idle | uploading | processing | review
  const [docId, setDocId] = useState(null)
  const [doc, setDoc] = useState(null)
  const [flowError, setFlowError] = useState(null)
  const polls = useRef(0)

  /* Poll document until terminal status */
  useEffect(() => {
    if (phase !== 'processing' || !docId) return
    let cancelled = false
    let timer
    const tick = async () => {
      try {
        const d = await api.adminGetDocument(docId)
        if (cancelled) return
        const status = d?.processing_status ?? 'needs_review'
        if (status === 'failed') {
          setFlowError(d?.error_message || 'The parser could not read this PDF.')
          setPhase('idle')
        } else if (TERMINAL.includes(status)) {
          setDoc(d)
          setPhase('review')
        } else if (++polls.current < 60) {
          timer = setTimeout(tick, 2500)
        } else {
          setFlowError('Timed out waiting for the parser. Try again.')
          setPhase('idle')
        }
      } catch (e) {
        if (!cancelled) {
          setFlowError(errMsg(e))
          setPhase('idle')
        }
      }
    }
    timer = setTimeout(tick, 1200)
    return () => {
      cancelled = true
      clearTimeout(timer)
    }
  }, [phase, docId])

  const uploadMut = useMutation({
    mutationFn: (file) => api.adminUploadPdf(tournamentId, file),
    onSuccess: (res) => {
      const id = res?.document_id ?? res?.id
      if (id) {
        setDocId(id)
        const status = res?.processing_status
        if (status && TERMINAL.includes(status) && status !== 'failed') {
          // already processed inline — still fetch full doc for issues, but fall back to inline payload
          setPhase('processing')
        } else {
          setPhase('processing')
        }
      } else if (res?.extraction_result) {
        setDoc(res)
        setPhase('review')
      } else {
        setFlowError('Upload succeeded but no document was returned. Check the Builder — wrestlers may already be imported.')
        setPhase('idle')
      }
    },
    onError: (e) => {
      setFlowError(errMsg(e, 'Upload failed'))
      setPhase('idle')
    },
  })

  const confirmMut = useMutation({
    mutationFn: (payload) => api.adminConfirmDocument(docId ?? doc?.id ?? doc?.document_id, payload),
    onSuccess: () => {
      toast.success('Import confirmed', { body: 'Weights, wrestlers and brackets are built.' })
      onConfirmed?.()
    },
    onError: (e) => toast.error('Confirm failed', { body: errMsg(e) }),
  })

  const reset = () => {
    setPhase('idle')
    setDoc(null)
    setDocId(null)
    setFlowError(null)
    polls.current = 0
  }

  if (phase === 'review' && doc) {
    return (
      <ImportReview
        doc={doc}
        confirming={confirmMut.isPending}
        onConfirm={(payload) => confirmMut.mutate({ tournament_id: Number(tournamentId), ...payload })}
        onDiscard={onCancel ?? reset}
      />
    )
  }

  return (
    <div className="space-y-4">
      <PdfDropzone
        busy={phase === 'uploading' || phase === 'processing' || uploadMut.isPending}
        error={flowError}
        onSelect={(file) => {
          setFlowError(null)
          polls.current = 0
          setPhase('uploading')
          uploadMut.mutate(file)
        }}
      />
      {phase === 'processing' && (
        <Card className="flex items-center gap-3 p-4">
          <Loader2 size={18} className="animate-spin text-gold-500" />
          <div className="text-sm">
            <p className="font-semibold text-ink-100">Structuring bracket data…</p>
            <p className="text-xs text-ink-500">Upload → extract → structure → review. Hang tight.</p>
          </div>
        </Card>
      )}
      {phase === 'idle' && flowError && (
        <div className="flex justify-center">
          <Button variant="secondary" size="sm" onClick={reset}>
            <RotateCcw size={14} /> Try another file
          </Button>
        </div>
      )}
      {phase === 'idle' && !flowError && uploadMut.isSuccess === false && null}
      {phase === 'idle' && flowError == null && doc == null && (
        <p className="flex items-center justify-center gap-1.5 text-center text-[11px] text-ink-600">
          <CheckCircle2 size={11} /> Nothing is written to the tournament until you confirm the review.
        </p>
      )}
    </div>
  )
}

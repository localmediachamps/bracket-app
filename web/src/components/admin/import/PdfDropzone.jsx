import React, { useRef, useState } from 'react'
import { FileUp, FileText, Loader2 } from 'lucide-react'
import { cn } from '../../../lib/utils'

const MAX_BYTES = 20 * 1024 * 1024

/**
 * PDF dropzone — drag + click. Validates type + ≤20MB.
 * props: onSelect(file), busy, error (string)
 */
export default function PdfDropzone({ onSelect, busy, error }) {
  const inputRef = useRef(null)
  const [dragging, setDragging] = useState(false)
  const [localError, setLocalError] = useState(null)

  const handle = (file) => {
    setLocalError(null)
    if (!file) return
    const isPdf = file.type === 'application/pdf' || /\.pdf$/i.test(file.name)
    if (!isPdf) return setLocalError('Only PDF files are accepted.')
    if (file.size > MAX_BYTES) return setLocalError(`File is ${(file.size / 1048576).toFixed(1)} MB — max 20 MB.`)
    onSelect(file)
  }

  const shown = localError || error

  return (
    <div>
      <button
        type="button"
        disabled={busy}
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => {
          e.preventDefault()
          setDragging(true)
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={(e) => {
          e.preventDefault()
          setDragging(false)
          handle(e.dataTransfer?.files?.[0])
        }}
        className={cn(
          'flex w-full flex-col items-center justify-center gap-3 rounded-2xl border-2 border-dashed px-6 py-14 text-center transition-all',
          dragging ? 'border-gold-500 bg-gold-500/8 scale-[1.01]' : 'border-mat-600 bg-mat-900/50 hover:border-gold-500/50 hover:bg-mat-900',
          busy && 'cursor-wait opacity-70',
          shown && 'border-blood-500/60'
        )}
        aria-label="Upload bracket PDF"
      >
        <span className={cn('flex h-14 w-14 items-center justify-center rounded-2xl transition-colors', dragging ? 'bg-gold-500 text-mat-950' : 'bg-mat-800 text-gold-500')}>
          {busy ? <Loader2 size={26} className="animate-spin" /> : <FileUp size={26} />}
        </span>
        <span>
          <span className="block font-display text-sm uppercase tracking-wide text-ink-100">
            {busy ? 'Uploading & parsing…' : dragging ? 'Drop it on the mat' : 'Drop bracket PDF here'}
          </span>
          <span className="mt-1 block text-xs text-ink-500">
            {busy ? 'The AI is reading seeds, names and schools — this can take up to a minute.' : 'or click to browse · PDF only · up to 20 MB'}
          </span>
        </span>
        {!busy && (
          <span className="inline-flex items-center gap-1.5 rounded-full bg-mat-800 px-3 py-1 text-[11px] font-bold text-ink-400">
            <FileText size={12} /> NCAA bracket sheets work best
          </span>
        )}
      </button>
      <input
        ref={inputRef}
        type="file"
        accept="application/pdf,.pdf"
        className="hidden"
        onChange={(e) => {
          handle(e.target.files?.[0])
          e.target.value = ''
        }}
      />
      {shown && <p className="mt-2 text-xs font-semibold text-blood-400">{shown}</p>}
    </div>
  )
}

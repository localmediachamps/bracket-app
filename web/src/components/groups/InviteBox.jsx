import React from 'react'
import { Copy, Link2 } from 'lucide-react'
import { toast } from '../../lib/store'
import { Button } from '../ui'

export async function copyText(text, what = 'Copied') {
  try {
    await navigator.clipboard.writeText(text)
    toast.success(what)
  } catch {
    // clipboard API can fail (permissions / non-secure context) — fall back
    const ta = document.createElement('textarea')
    ta.value = text
    ta.style.position = 'fixed'
    ta.style.opacity = '0'
    document.body.appendChild(ta)
    ta.select()
    try {
      document.execCommand('copy')
      toast.success(what)
    } catch {
      toast.error('Copy failed', { body: 'Select and copy it manually.' })
    }
    document.body.removeChild(ta)
  }
}

export function inviteLink(groupId, code) {
  return `${window.location.origin}/groups/${groupId}${code ? `?code=${encodeURIComponent(code)}` : ''}`
}

/**
 * InviteBox — invite code (mono) + copy code / copy link buttons.
 */
export default function InviteBox({ groupId, code, big = false, className }) {
  if (!code) return null
  return (
    <div className={className}>
      <div className="flex flex-wrap items-center gap-3">
        <span
          className={
            big
              ? 'rounded-2xl border border-gold-500/40 bg-mat-900 px-6 py-4 font-mono text-3xl font-bold tracking-[0.3em] text-gold-400 shadow-glow-sm'
              : 'rounded-xl border border-mat-600 bg-mat-900 px-4 py-2.5 font-mono text-lg font-bold tracking-[0.25em] text-gold-400'
          }
        >
          {code}
        </span>
        <div className="flex flex-wrap gap-2">
          <Button variant="secondary" size={big ? 'md' : 'sm'} onClick={() => copyText(code, 'Invite code copied')}>
            <Copy size={14} /> Copy code
          </Button>
          <Button variant="secondary" size={big ? 'md' : 'sm'} onClick={() => copyText(inviteLink(groupId, code), 'Invite link copied')}>
            <Link2 size={14} /> Copy invite link
          </Button>
        </div>
      </div>
    </div>
  )
}

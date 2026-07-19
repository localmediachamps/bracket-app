import React, { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { KeyRound } from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Button, Card, Input } from '../ui'

/**
 * JoinWithCode — invite-code input + join button.
 * onJoined(membership, code) optional callback (e.g. navigate).
 */
export default function JoinWithCode({ initialCode = '', onJoined, className }) {
  const [code, setCode] = useState(initialCode)
  const [error, setError] = useState(null)
  const qc = useQueryClient()

  const mutation = useMutation({
    mutationFn: (inviteCode) => api.joinGroup(inviteCode),
    onSuccess: (data, inviteCode) => {
      toast.success('Welcome to the group', { body: 'You joined successfully.' })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['group'] })
      setError(null)
      onJoined?.(data, inviteCode)
    },
    onError: (err) => setError(err.message || 'Could not join with that code.'),
  })

  const submit = (e) => {
    e?.preventDefault()
    const c = code.trim()
    if (!c) {
      setError('Enter an invite code.')
      return
    }
    mutation.mutate(c)
  }

  return (
    <Card className={className}>
      <form onSubmit={submit} className="flex h-full flex-col justify-center gap-3 p-4">
        <div className="flex items-center gap-2 text-sm font-bold text-ink-100">
          <KeyRound size={15} className="text-gold-500" />
          Join with a code
        </div>
        <div className="flex gap-2">
          <Input
            value={code}
            onChange={(e) => {
              setCode(e.target.value.toUpperCase())
              setError(null)
            }}
            placeholder="e.g. 8XKQ2MPT"
            aria-label="Group invite code"
            className="font-mono uppercase tracking-widest"
            error={error}
            maxLength={16}
          />
          <Button type="submit" loading={mutation.isPending} className="shrink-0">
            Join
          </Button>
        </div>
      </form>
    </Card>
  )
}

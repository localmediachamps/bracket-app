import React, { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Search, UserPlus } from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Avatar, Button, Card, Input } from '../ui'

/**
 * InviteMemberBox — look up an existing account by exact username, then
 * invite them. Leagues are invite-only by account, no open join code.
 */
export default function InviteMemberBox({ leagueId, className }) {
  const qc = useQueryClient()
  const [username, setUsername] = useState('')
  const [found, setFound] = useState(undefined) // undefined = not searched, null = no match, object = match
  const [searching, setSearching] = useState(false)

  const search = async () => {
    const u = username.trim()
    if (!u) return
    setSearching(true)
    try {
      const result = await api.lookupLeagueUser(u)
      setFound(result)
    } catch (err) {
      toast.error('Lookup failed', { body: err.message })
      setFound(null)
    } finally {
      setSearching(false)
    }
  }

  const inviteMutation = useMutation({
    mutationFn: () => api.inviteToLeague(leagueId, found.id),
    onSuccess: () => {
      toast.success(`Invited ${found.display_name || found.username}`)
      setFound(undefined)
      setUsername('')
      qc.invalidateQueries({ queryKey: ['league', String(leagueId)] })
    },
    onError: (err) => toast.error('Could not send invite', { body: err.message }),
  })

  return (
    <Card className={'p-4 ' + (className ?? '')}>
      <div className="mb-2.5 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Invite a member</div>
      <div className="flex gap-2">
        <Input
          value={username}
          onChange={(e) => {
            setUsername(e.target.value)
            setFound(undefined)
          }}
          onKeyDown={(e) => e.key === 'Enter' && search()}
          placeholder="Their exact username"
          className="flex-1"
        />
        <Button variant="secondary" onClick={search} loading={searching} disabled={!username.trim()}>
          <Search size={15} />
        </Button>
      </div>

      {found === null && <p className="mt-2 text-xs text-blood-400">No account with that username.</p>}

      {found && (
        <div className="mt-3 flex items-center justify-between gap-3 rounded-lg border border-mat-700 bg-mat-800 p-3">
          <div className="flex min-w-0 items-center gap-2.5">
            <Avatar user={found} size="sm" />
            <span className="truncate text-sm font-semibold text-ink-100">
              {found.display_name || found.username}
            </span>
          </div>
          <Button size="sm" onClick={() => inviteMutation.mutate()} loading={inviteMutation.isPending}>
            <UserPlus size={14} /> Invite
          </Button>
        </div>
      )}
    </Card>
  )
}

import React, { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { AlertTriangle, Check, Hash, Plus, RotateCcw, ShieldAlert, Trash2 } from 'lucide-react'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Badge, Button, Card, EmptyState, Input, Skeleton } from '../../components/ui'
import { PageHeader, ErrorState } from '../../components/admin/AdminCommon'
import { timeAgo } from '../../components/admin/adminUtils'

function FlaggedQueue() {
  const qc = useQueryClient()
  const q = useQuery({
    queryKey: ['admin', 'board-flagged'],
    queryFn: () => api.adminBoardFlagged(),
  })

  const resolveMutation = useMutation({
    mutationFn: ({ postId, action }) => api.adminResolveBoardPost(postId, action),
    onSuccess: (_, { action }) => {
      toast.success(action === 'restore' ? 'Post restored' : action === 'strike' ? 'Strike applied' : 'Post deleted')
      qc.invalidateQueries({ queryKey: ['admin', 'board-flagged'] })
    },
    onError: (err) => toast.error('Could not resolve', { body: err.message }),
  })

  const items = q.data?.items ?? []

  if (q.isLoading) {
    return (
      <div className="space-y-2">
        <Skeleton className="h-24 w-full" />
        <Skeleton className="h-24 w-full" />
      </div>
    )
  }

  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} title="Couldn't load flagged posts" />

  if (items.length === 0) {
    return <EmptyState icon={<ShieldAlert size={22} />} title="Queue is clear" body="Flagged posts (from AI or user reports) will show up here for review." />
  }

  return (
    <div className="space-y-3">
      {items.map((p) => (
        <Card key={p.id} className="p-4">
          <div className="mb-2 flex flex-wrap items-center gap-2">
            <Badge color={p.flag_source === 'ai' ? 'gold' : 'blood'}>{p.flag_source === 'ai' ? 'AI flagged' : 'User reported'}</Badge>
            <span className="text-xs text-ink-500">{timeAgo(p.created_at)}</span>
            <span className="text-xs text-ink-600">·</span>
            <span className="text-xs text-ink-500">{p.league_name ? `League: ${p.league_name}` : `#${p.channel_name}`}</span>
            <span className="ml-auto text-xs text-ink-500">
              by <span className="font-semibold text-ink-300">{p.author_display_name || p.author_username || 'Unknown'}</span>
              {p.author_strike_count > 0 && <span className="ml-1.5 text-blood-400">({p.author_strike_count} prior strike{p.author_strike_count === 1 ? '' : 's'})</span>}
            </span>
          </div>

          <p className="mb-2 whitespace-pre-wrap rounded-lg border border-mat-700 bg-mat-850 p-3 text-sm text-ink-200">{p.body}</p>
          {p.flag_reason && (
            <p className="mb-3 flex items-start gap-1.5 text-xs text-ink-500">
              <AlertTriangle size={13} className="mt-0.5 shrink-0 text-gold-500" /> {p.flag_reason}
            </p>
          )}

          <div className="flex flex-wrap gap-2">
            <Button
              size="sm"
              variant="secondary"
              loading={resolveMutation.isPending}
              onClick={() => resolveMutation.mutate({ postId: p.id, action: 'restore' })}
            >
              <RotateCcw size={14} /> Restore
            </Button>
            <Button
              size="sm"
              variant="secondary"
              loading={resolveMutation.isPending}
              onClick={() => resolveMutation.mutate({ postId: p.id, action: 'delete' })}
            >
              <Trash2 size={14} /> Delete (no strike)
            </Button>
            <Button
              size="sm"
              variant="danger"
              loading={resolveMutation.isPending}
              onClick={() => resolveMutation.mutate({ postId: p.id, action: 'strike' })}
            >
              <ShieldAlert size={14} /> Delete + strike account
            </Button>
          </div>
        </Card>
      ))}
    </div>
  )
}

function ChannelManager() {
  const qc = useQueryClient()
  const [newName, setNewName] = useState('')
  const [newDescription, setNewDescription] = useState('')

  const q = useQuery({
    queryKey: ['admin', 'board-channels'],
    queryFn: () => api.boardChannels(),
  })

  const createMutation = useMutation({
    mutationFn: () => api.adminCreateBoardChannel({ name: newName, description: newDescription || undefined }),
    onSuccess: () => {
      toast.success('Channel created')
      setNewName('')
      setNewDescription('')
      qc.invalidateQueries({ queryKey: ['admin', 'board-channels'] })
      qc.invalidateQueries({ queryKey: ['board-channels'] })
    },
    onError: (err) => toast.error('Could not create channel', { body: err.message }),
  })

  const archiveMutation = useMutation({
    mutationFn: ({ channelId, archived }) => api.adminUpdateBoardChannel(channelId, { archived }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'board-channels'] })
      qc.invalidateQueries({ queryKey: ['board-channels'] })
    },
    onError: (err) => toast.error('Could not update channel', { body: err.message }),
  })

  return (
    <div className="space-y-4">
      <Card className="space-y-3 p-4">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-500">New channel</p>
        <div className="flex flex-wrap gap-2">
          <Input value={newName} onChange={(e) => setNewName(e.target.value)} placeholder="Channel name, e.g. General" className="flex-1" />
          <Input value={newDescription} onChange={(e) => setNewDescription(e.target.value)} placeholder="Description (optional)" className="flex-1" />
          <Button onClick={() => createMutation.mutate()} loading={createMutation.isPending} disabled={!newName.trim()}>
            <Plus size={14} /> Create
          </Button>
        </div>
      </Card>

      <div className="space-y-2">
        {(q.data ?? []).map((c) => (
          <Card key={c.id} className="flex items-center gap-3 p-3">
            <Hash size={15} className="shrink-0 text-ink-500" />
            <div className="min-w-0 flex-1">
              <p className="text-sm font-bold text-ink-100">{c.name}</p>
              {c.description && <p className="truncate text-xs text-ink-500">{c.description}</p>}
            </div>
            {c.archived ? (
              <Button size="sm" variant="secondary" onClick={() => archiveMutation.mutate({ channelId: c.id, archived: false })}>
                <Check size={14} /> Unarchive
              </Button>
            ) : (
              <Button size="sm" variant="ghost" onClick={() => archiveMutation.mutate({ channelId: c.id, archived: true })}>
                Archive
              </Button>
            )}
          </Card>
        ))}
      </div>
    </div>
  )
}

export default function AdminBoard() {
  return (
    <div>
      <PageHeader title="Message Board" sub="Moderation queue and channel management for the league boards and the platform-wide community board." />

      <div className="mb-6">
        <p className="mb-3 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Flagged posts</p>
        <FlaggedQueue />
      </div>

      <div>
        <p className="mb-3 text-[10px] font-bold uppercase tracking-[0.16em] text-ink-500">Community channels</p>
        <ChannelManager />
      </div>
    </div>
  )
}

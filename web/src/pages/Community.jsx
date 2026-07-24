import React, { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Hash, MessageSquare } from 'lucide-react'
import { api } from '../lib/api'
import { toast, useAuthStore } from '../lib/store'
import { Card, Skeleton } from '../components/ui'
import { cn } from '../lib/utils'
import BoardFeed from '../components/board/BoardFeed'

/** Platform-wide master message board - Discord/Slack-style channels,
 * admin-created (see /admin/board), open to every user to read and post
 * within. */
export default function Community() {
  const qc = useQueryClient()
  const me = useAuthStore((s) => s.user)
  const [activeChannelId, setActiveChannelId] = useState(null)
  const [sort, setSort] = useState('recent')

  const { data: channels, isLoading: channelsLoading } = useQuery({
    queryKey: ['board-channels'],
    queryFn: () => api.boardChannels(),
  })

  useEffect(() => {
    if (!activeChannelId && channels?.length) {
      setActiveChannelId(channels[0].id)
    }
  }, [channels, activeChannelId])

  const { data, isLoading: postsLoading } = useQuery({
    queryKey: ['board-posts', activeChannelId, sort],
    queryFn: () => api.boardPosts(activeChannelId, sort),
    enabled: activeChannelId != null,
  })

  const postMutation = useMutation({
    mutationFn: ({ body, parentPostId }) => api.postToBoard(activeChannelId, body, parentPostId ?? undefined),
    onError: (err) => toast.error('Could not post', { body: err.message }),
  })

  const reportMutation = useMutation({
    mutationFn: (postId) => api.reportBoardPost(postId),
    onError: (err) => toast.error('Could not report', { body: err.message }),
  })

  const likeMutation = useMutation({
    mutationFn: (postId) => api.likeBoardPost(postId),
  })

  const handleSubmit = (body, parentPostId, { onSuccess }) => {
    postMutation.mutate(
      { body, parentPostId },
      {
        onSuccess: () => {
          onSuccess()
          qc.invalidateQueries({ queryKey: ['board-posts', activeChannelId] })
        },
      }
    )
  }

  const handleReport = (postId) => {
    reportMutation.mutate(postId, {
      onSuccess: () => qc.invalidateQueries({ queryKey: ['board-posts', activeChannelId] }),
    })
  }

  const handleLike = (postId, { onError }) => {
    likeMutation.mutate(postId, {
      onError: (err) => {
        toast.error('Could not update like', { body: err.message })
        onError()
      },
    })
  }

  const activeChannel = (channels ?? []).find((c) => c.id === activeChannelId)

  return (
    <div className="mx-auto max-w-5xl px-4 py-6">
      <div className="mb-5 flex items-center gap-2.5">
        <MessageSquare size={20} className="text-gold-400" />
        <h1 className="font-display text-xl uppercase tracking-tight text-ink-100">Community</h1>
      </div>

      <div className="flex flex-col gap-5 lg:flex-row">
        <Card className="shrink-0 p-2 lg:w-56">
          <p className="mb-1 px-2 pt-1 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">Channels</p>
          {channelsLoading ? (
            <div className="space-y-1.5 p-1">
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
            </div>
          ) : (channels ?? []).length === 0 ? (
            <p className="px-2 py-3 text-xs text-ink-600">No channels yet.</p>
          ) : (
            <nav className="flex gap-1 overflow-x-auto lg:flex-col lg:overflow-visible">
              {channels.map((c) => (
                <button
                  key={c.id}
                  onClick={() => setActiveChannelId(c.id)}
                  className={cn(
                    'flex items-center gap-1.5 whitespace-nowrap rounded-lg px-2.5 py-2 text-left text-sm font-semibold transition-colors',
                    activeChannelId === c.id ? 'bg-mat-800 text-gold-400' : 'text-ink-400 hover:bg-mat-850 hover:text-ink-100'
                  )}
                >
                  <Hash size={13} className="shrink-0" />
                  {c.name}
                </button>
              ))}
            </nav>
          )}
        </Card>

        <div className="min-w-0 flex-1">
          {activeChannel?.description && <p className="mb-3 text-xs text-ink-500">{activeChannel.description}</p>}
          <BoardFeed
            posts={data?.items}
            isLoading={postsLoading}
            currentUserId={me?.id}
            onSubmit={handleSubmit}
            submitting={postMutation.isPending}
            onReport={handleReport}
            onLike={handleLike}
            sort={sort}
            onSortChange={setSort}
            emptyMessage="No messages yet in this channel."
            placeholder={activeChannel ? `Message #${activeChannel.name}...` : 'Message...'}
          />
        </div>
      </div>
    </div>
  )
}

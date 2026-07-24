import React, { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, MessageSquare } from 'lucide-react'
import { api } from '../lib/api'
import { toast, useAuthStore } from '../lib/store'
import BoardFeed from '../components/board/BoardFeed'

export default function LeagueMessageBoard() {
  const { id } = useParams()
  const qc = useQueryClient()
  const me = useAuthStore((s) => s.user)
  const [sort, setSort] = useState('recent')

  const { data: leagueData } = useQuery({
    queryKey: ['league', id],
    queryFn: () => api.league(id),
  })

  const myMembership = leagueData?.my_membership
  const isCommissioner = myMembership?.role === 'owner' || myMembership?.role === 'commissioner'

  const { data, isLoading } = useQuery({
    queryKey: ['league-board', id, sort],
    queryFn: () => api.leagueBoard(id, sort),
  })

  const postMutation = useMutation({
    mutationFn: ({ body, parentPostId }) => api.postToLeagueBoard(id, body, parentPostId ?? undefined),
    onError: (err) => toast.error('Could not post', { body: err.message }),
  })

  const reportMutation = useMutation({
    mutationFn: (postId) => api.reportBoardPost(postId),
    onError: (err) => toast.error('Could not report', { body: err.message }),
  })

  const likeMutation = useMutation({
    mutationFn: (postId) => api.likeBoardPost(postId),
  })

  const deleteMutation = useMutation({
    mutationFn: (postId) => api.deleteLeagueBoardPost(postId),
    onSuccess: () => {
      toast.success('Post deleted')
      qc.invalidateQueries({ queryKey: ['league-board', id] })
    },
    onError: (err) => toast.error('Could not delete', { body: err.message }),
  })

  const handleSubmit = (body, parentPostId, { onSuccess }) => {
    postMutation.mutate(
      { body, parentPostId },
      {
        onSuccess: () => {
          onSuccess()
          qc.invalidateQueries({ queryKey: ['league-board', id] })
        },
      }
    )
  }

  const handleReport = (postId) => {
    reportMutation.mutate(postId, {
      onSuccess: () => qc.invalidateQueries({ queryKey: ['league-board', id] }),
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

  return (
    <div className="mx-auto max-w-2xl space-y-5 px-4 py-6">
      <Link to={`/leagues/${id}`} className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-ink-100">
        <ArrowLeft size={15} /> Back to league
      </Link>

      <div className="flex items-center gap-2.5">
        <MessageSquare size={20} className="text-gold-400" />
        <h1 className="font-display text-xl uppercase tracking-tight text-ink-100">
          {leagueData?.name ? `${leagueData.name} — Message Board` : 'Message Board'}
        </h1>
      </div>

      <BoardFeed
        posts={data?.items}
        isLoading={isLoading}
        currentUserId={me?.id}
        isCommissioner={isCommissioner}
        onSubmit={handleSubmit}
        submitting={postMutation.isPending}
        onReport={handleReport}
        onDelete={(postId) => deleteMutation.mutate(postId)}
        onLike={handleLike}
        sort={sort}
        onSortChange={setSort}
        emptyMessage="No messages yet - be the first to post to your league."
        placeholder="Talk trades, trash-talk your rivals, plan your lineup..."
      />
    </div>
  )
}

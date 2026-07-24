import React, { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Flag, Heart, MessageCircle, MessageSquare, Send, Trash2 } from 'lucide-react'
import { api } from '../../lib/api'
import { Avatar, Button, Card, EmptyState, Skeleton } from '../ui'
import { toast } from '../../lib/store'
import { cn } from '../../lib/utils'

const SORTS = [
  { key: 'recent', label: 'Recent' },
  { key: 'top', label: 'Top' },
  { key: 'discussed', label: 'Most discussed' },
]

function timeAgo(ms) {
  const diff = Date.now() - ms
  const min = Math.floor(diff / 60000)
  if (min < 1) return 'just now'
  if (min < 60) return `${min}m ago`
  const hr = Math.floor(min / 60)
  if (hr < 24) return `${hr}h ago`
  const day = Math.floor(hr / 24)
  if (day < 7) return `${day}d ago`
  return new Date(ms).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

// One post/reply row - recursive: a reply thread is rendered by nesting
// this same component one level deeper, since board_post's parent_post_id
// self-reference supports arbitrary depth even though the UI here only
// lazy-expands one level at a time (matches how board/post/replies fetches
// direct replies only, not the whole tree at once).
function PostRow({ post, currentUserId, isCommissioner, onReport, onDelete, onReply, onLike, depth = 0 }) {
  const [repliesOpen, setRepliesOpen] = useState(false)
  const [replyDraft, setReplyDraft] = useState('')
  const [reporting, setReporting] = useState(false)
  const [liked, setLiked] = useState(!!post.liked_by_me)
  const [likeCount, setLikeCount] = useState(post.like_count ?? 0)
  const qc = useQueryClient()

  const { data: replies, isLoading: repliesLoading } = useQuery({
    queryKey: ['board-replies', post.id],
    queryFn: () => api.boardPostReplies(post.id),
    enabled: repliesOpen,
  })

  const author = { display_name: post.author_display_name, username: post.author_username, avatar_url: post.author_avatar_url }
  const isMine = post.user_id === currentUserId

  const toggleLike = () => {
    const nextLiked = !liked
    setLiked(nextLiked)
    setLikeCount((c) => c + (nextLiked ? 1 : -1))
    onLike(post.id, {
      onError: () => {
        setLiked(!nextLiked)
        setLikeCount((c) => c + (nextLiked ? -1 : 1))
      },
    })
  }

  const submitReply = () => {
    const body = replyDraft.trim()
    if (!body) return
    onReply(body, post.id, {
      onSuccess: () => {
        setReplyDraft('')
        setRepliesOpen(true)
        qc.invalidateQueries({ queryKey: ['board-replies', post.id] })
      },
    })
  }

  const report = () => {
    onReport(post.id)
    setReporting(true)
    toast.success('Reported - hidden pending review')
  }

  return (
    <Card className={depth > 0 ? 'flex gap-3 border-mat-750 bg-mat-900/40 p-3' : 'flex gap-3 p-3'}>
      <Avatar user={author} size={depth > 0 ? 'xs' : 'sm'} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-baseline gap-2">
          <span className="text-sm font-bold text-ink-100">{author.display_name || author.username || 'Member'}</span>
          <span className="text-xs text-ink-600">{timeAgo(post.created_at)}</span>
        </div>
        <p className="mt-0.5 whitespace-pre-wrap break-words text-sm text-ink-200">{post.body}</p>

        <div className="mt-1.5 flex items-center gap-3">
          <button
            type="button"
            onClick={toggleLike}
            className={cn('flex items-center gap-1 text-xs font-semibold', liked ? 'text-blood-400' : 'text-ink-500 hover:text-blood-400')}
          >
            <Heart size={13} className={liked ? 'fill-current' : ''} />
            {likeCount > 0 ? likeCount : 'Like'}
          </button>
          <button
            type="button"
            onClick={() => setRepliesOpen((v) => !v)}
            className="flex items-center gap-1 text-xs font-semibold text-ink-500 hover:text-gold-400"
          >
            <MessageCircle size={13} />
            {post.reply_count > 0 ? `${post.reply_count} repl${post.reply_count === 1 ? 'y' : 'ies'}` : 'Reply'}
          </button>
          {(isMine || isCommissioner) && onDelete && (
            <button type="button" onClick={() => onDelete(post.id)} className="flex items-center gap-1 text-xs font-semibold text-ink-600 hover:text-blood-400">
              <Trash2 size={13} /> Delete
            </button>
          )}
          {!isMine && (
            <button
              type="button"
              disabled={reporting}
              onClick={report}
              className="flex items-center gap-1 text-xs font-semibold text-ink-600 hover:text-gold-400 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <Flag size={13} /> {reporting ? 'Reported' : 'Report'}
            </button>
          )}
        </div>

        {repliesOpen && (
          <div className="mt-3 space-y-2 border-l-2 border-mat-750 pl-3">
            <div className="flex gap-2">
              <input
                value={replyDraft}
                onChange={(e) => setReplyDraft(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && submitReply()}
                placeholder="Write a reply..."
                className="flex-1 rounded-lg border border-mat-700 bg-mat-850 px-2.5 py-1.5 text-sm text-ink-100 placeholder:text-ink-600 focus:border-gold-500/50 focus:outline-none"
              />
              <Button size="xs" onClick={submitReply} disabled={!replyDraft.trim()}>
                <Send size={12} />
              </Button>
            </div>

            {repliesLoading ? (
              <Skeleton className="h-10 w-full" />
            ) : (replies ?? []).length === 0 ? (
              <p className="text-xs text-ink-600">No replies yet.</p>
            ) : (
              <div className="space-y-2">
                {replies.map((r) => (
                  <PostRow
                    key={r.id}
                    post={r}
                    currentUserId={currentUserId}
                    isCommissioner={isCommissioner}
                    onReport={onReport}
                    onDelete={onDelete}
                    onReply={onReply}
                    onLike={onLike}
                    depth={depth + 1}
                  />
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </Card>
  )
}

// Shared flat-feed UI for both the per-league message board and the
// platform-wide master board channels - same shape (composer up top, newest
// top-level post first, Reddit-style expandable reply threads under each),
// the only difference is what data/mutations the parent page wires up
// (leagues/board/* vs board/*).
export default function BoardFeed({
  posts,
  isLoading,
  currentUserId,
  isCommissioner = false,
  onSubmit,
  submitting,
  onReport,
  onDelete,
  onLike,
  sort = 'recent',
  onSortChange,
  emptyMessage = 'No messages yet - be the first to post.',
  placeholder = 'Share something with the league...',
}) {
  const [draft, setDraft] = useState('')

  const submit = () => {
    const body = draft.trim()
    if (!body) return
    onSubmit(body, null, {
      onSuccess: () => setDraft(''),
    })
  }

  return (
    <div className="space-y-4">
      <Card className="space-y-2 p-3">
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder={placeholder}
          rows={2}
          className="w-full resize-none rounded-lg border border-mat-700 bg-mat-850 px-3 py-2 text-sm text-ink-100 placeholder:text-ink-600 focus:border-gold-500/50 focus:outline-none"
        />
        <div className="flex justify-end">
          <Button size="sm" onClick={submit} loading={submitting} disabled={!draft.trim()}>
            <Send size={14} /> Post
          </Button>
        </div>
      </Card>

      {onSortChange && (
        <div className="flex gap-1.5">
          {SORTS.map((s) => (
            <button
              key={s.key}
              onClick={() => onSortChange(s.key)}
              className={cn(
                'rounded-full px-3 py-1 text-xs font-semibold transition-colors',
                sort === s.key ? 'bg-gold-500/15 text-gold-400' : 'text-ink-500 hover:bg-mat-800 hover:text-ink-200'
              )}
            >
              {s.label}
            </button>
          ))}
        </div>
      )}

      {isLoading ? (
        <div className="space-y-2">
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
        </div>
      ) : (posts ?? []).length === 0 ? (
        <EmptyState icon={<MessageSquare size={22} />} title="Quiet in here" body={emptyMessage} />
      ) : (
        <div className="space-y-2">
          {posts.map((p) => (
            <PostRow
              key={p.id}
              post={p}
              currentUserId={currentUserId}
              isCommissioner={isCommissioner}
              onReport={onReport}
              onDelete={onDelete}
              onReply={onSubmit}
              onLike={onLike}
            />
          ))}
        </div>
      )}
    </div>
  )
}

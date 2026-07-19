import React, { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../../lib/api'
import { toast } from '../../lib/store'
import { Button, Input, Modal, Textarea } from '../ui'
import EmojiPicker from './EmojiPicker'
import PrivacyCards from './PrivacyCards'

/**
 * EditGroupModal — owner/admin edit of name, description, privacy, limit, emoji.
 */
export default function EditGroupModal({ open, onClose, group }) {
  const qc = useQueryClient()
  const [form, setForm] = useState({ name: '', description: '', privacy: 'private', member_limit: '', avatar_emoji: '🤼' })
  const [error, setError] = useState(null)

  useEffect(() => {
    if (open && group) {
      setForm({
        name: group.name ?? '',
        description: group.description ?? '',
        privacy: group.privacy ?? 'private',
        member_limit: group.member_limit ?? '',
        avatar_emoji: group.avatar_emoji || '🤼',
      })
      setError(null)
    }
  }, [open, group])

  const mutation = useMutation({
    mutationFn: (payload) => api.updateGroup(group.id, payload),
    onSuccess: () => {
      toast.success('Group updated')
      qc.invalidateQueries({ queryKey: ['group', String(group.id)] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      onClose()
    },
    onError: (err) => setError(err.message || 'Could not save changes.'),
  })

  const submit = (e) => {
    e?.preventDefault()
    if (!form.name.trim()) {
      setError('Give the group a name.')
      return
    }
    mutation.mutate({
      name: form.name.trim(),
      description: form.description.trim() || null,
      privacy: form.privacy,
      member_limit: form.member_limit === '' || form.member_limit == null ? null : Number(form.member_limit),
      avatar_emoji: form.avatar_emoji,
    })
  }

  const set = (k) => (e) => {
    setForm((f) => ({ ...f, [k]: e.target.value }))
    setError(null)
  }

  return (
    <Modal open={open} onClose={onClose} title="Edit group">
      <form onSubmit={submit} className="space-y-4">
        <div className="flex items-center gap-3">
          <span className="flex h-12 w-12 items-center justify-center rounded-xl border border-mat-600 bg-mat-800 text-2xl" aria-hidden>
            {form.avatar_emoji}
          </span>
          <div className="flex-1">
            <Input label="Name" value={form.name} onChange={set('name')} maxLength={60} required />
          </div>
        </div>
        <Textarea label="Description" value={form.description} onChange={set('description')} rows={2} maxLength={280} placeholder="What's this group about?" />
        <div>
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">Privacy</span>
          <PrivacyCards value={form.privacy} onChange={(v) => setForm((f) => ({ ...f, privacy: v }))} />
        </div>
        <Input
          label="Member limit"
          type="number"
          min={2}
          max={500}
          value={form.member_limit}
          onChange={set('member_limit')}
          placeholder="No limit"
          hint="Leave blank for unlimited members."
        />
        <div>
          <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">Avatar emoji</span>
          <EmojiPicker value={form.avatar_emoji} onChange={(v) => setForm((f) => ({ ...f, avatar_emoji: v }))} />
        </div>
        {error && <p className="text-xs font-semibold text-blood-400">{error}</p>}
        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" loading={mutation.isPending}>
            Save changes
          </Button>
        </div>
      </form>
    </Modal>
  )
}

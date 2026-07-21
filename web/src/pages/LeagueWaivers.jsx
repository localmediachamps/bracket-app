import React, { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { ArrowLeft, Plus } from 'lucide-react'
import { api } from '../lib/api'
import { toast } from '../lib/store'
import { Button, Card, Modal, Select, Skeleton } from '../components/ui'

export default function LeagueWaivers() {
  const { id } = useParams()
  const qc = useQueryClient()
  const [page, setPage] = useState(1)
  const [claimTarget, setClaimTarget] = useState(null)
  const [dropSlotId, setDropSlotId] = useState('')

  const { data, isLoading } = useQuery({
    queryKey: ['waivers-available', id, page],
    queryFn: () => api.waiversAvailable(id, { page }),
  })

  const { data: myRoster } = useQuery({
    queryKey: ['my-roster-for-waivers', id],
    queryFn: async () => {
      const weeks = await api.leagueWeeks(id)
      const week = weeks?.[0]
      if (!week) return []
      const lineup = await api.leagueLineup(id, week.id)
      return lineup?.roster ?? []
    },
  })

  useEffect(() => {
    if (!dropSlotId && myRoster?.length) setDropSlotId(String(myRoster[0].roster_slot_id))
  }, [myRoster, dropSlotId])

  const claimMutation = useMutation({
    mutationFn: () => api.claimWaiver(id, claimTarget.id, Number(dropSlotId)),
    onSuccess: () => {
      toast.success(`Claimed ${claimTarget.display_name}`)
      setClaimTarget(null)
      qc.invalidateQueries({ queryKey: ['waivers-available', id] })
      qc.invalidateQueries({ queryKey: ['my-roster-for-waivers', id] })
    },
    onError: (err) => toast.error('Claim failed', { body: err.message }),
  })

  return (
    <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} className="space-y-6 py-6">
      <Link to={`/leagues/${id}`} className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to league
      </Link>

      <h1 className="font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">
        Waiver <span className="text-gold-400">Wire</span>
      </h1>
      <p className="text-sm text-ink-500">Claims resolve instantly, first-come — pick who you're dropping to make room.</p>

      {isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-14 w-full" />
          ))}
        </div>
      ) : (
        <Card className="divide-y divide-mat-700 p-0">
          {(data?.wrestlers ?? []).map((w) => (
            <div key={w.id} className="flex items-center justify-between gap-3 p-4">
              <div className="min-w-0">
                <div className="truncate text-sm font-semibold text-ink-100">{w.display_name}</div>
              </div>
              <Button size="sm" disabled={!myRoster?.length} onClick={() => setClaimTarget(w)}>
                <Plus size={14} /> Claim
              </Button>
            </div>
          ))}
          {(data?.wrestlers ?? []).length === 0 && <p className="p-6 text-center text-sm text-ink-500">No available wrestlers on this page.</p>}
        </Card>
      )}

      <div className="flex justify-center gap-2">
        <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
          Previous
        </Button>
        <Button variant="secondary" size="sm" onClick={() => setPage((p) => p + 1)}>
          Next
        </Button>
      </div>

      <Modal open={!!claimTarget} onClose={() => setClaimTarget(null)} title="Claim wrestler?">
        {claimTarget && (
          <>
            <p className="text-sm text-ink-300">
              Claiming <span className="font-bold text-ink-100">{claimTarget.display_name}</span>. Choose who to drop to make room — the claim takes
              over that exact roster spot.
            </p>
            <Select className="mt-4" value={dropSlotId} onChange={(e) => setDropSlotId(e.target.value)}>
              {(myRoster ?? []).map((r) => (
                <option key={r.roster_slot_id} value={r.roster_slot_id}>
                  {r.wrestler?.display_name} ({r.slot_type})
                </option>
              ))}
            </Select>
            <div className="mt-5 flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setClaimTarget(null)}>
                Cancel
              </Button>
              <Button loading={claimMutation.isPending} disabled={!dropSlotId} onClick={() => claimMutation.mutate()}>
                Confirm claim
              </Button>
            </div>
          </>
        )}
      </Modal>
    </motion.div>
  )
}

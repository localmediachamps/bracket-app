import React, { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { ArrowLeft, Plus, Search } from 'lucide-react'
import { api } from '../lib/api'
import { toast } from '../lib/store'
import { Button, Card, Input, Modal, Select, Skeleton } from '../components/ui'
import CompetitionCard from '../components/wrestlers/CompetitionCard'

const WEIGHTS = ['125', '133', '141', '149', '157', '165', '174', '184', '197', '285']

export default function LeagueWaivers() {
  const { id } = useParams()
  const qc = useQueryClient()
  const [page, setPage] = useState(1)
  const [weightClass, setWeightClass] = useState('')
  const [teamId, setTeamId] = useState('')
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [claimTarget, setClaimTarget] = useState(null)
  const [dropSlotId, setDropSlotId] = useState('')

  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(search.trim()), 300)
    return () => clearTimeout(t)
  }, [search])

  useEffect(() => {
    setPage(1)
  }, [weightClass, teamId, debouncedSearch])

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['waivers-available', id, page, weightClass, teamId, debouncedSearch],
    queryFn: () =>
      api.waiversAvailable(id, {
        page,
        weight_class: weightClass || undefined,
        team_id: teamId || undefined,
        q: debouncedSearch || undefined,
      }),
  })

  const { data: teamsData } = useQuery({
    queryKey: ['teams-for-waiver-filter'],
    queryFn: () => api.teams(),
  })
  const teams = (teamsData?.teams ?? []).slice().sort((a, b) => a.name.localeCompare(b.name))

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
    mutationFn: () => api.claimWaiver(id, claimTarget.canonical_wrestler_id, Number(dropSlotId)),
    onSuccess: () => {
      toast.success(`Claimed ${claimTarget.display_name}`)
      setClaimTarget(null)
      qc.invalidateQueries({ queryKey: ['waivers-available', id] })
      qc.invalidateQueries({ queryKey: ['my-roster-for-waivers', id] })
    },
    onError: (err) => toast.error('Claim failed', { body: err.message }),
  })

  const wrestlers = data?.wrestlers ?? []

  return (
    <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} className="space-y-6 py-6">
      <Link to={`/leagues/${id}`} className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-400 hover:text-gold-400">
        <ArrowLeft size={15} /> Back to league
      </Link>

      <h1 className="font-display text-2xl uppercase tracking-tight text-ink-100 sm:text-3xl">
        Waiver <span className="text-gold-400">Wire</span>
      </h1>
      <p className="text-sm text-ink-500">Claims resolve instantly, first-come — pick who you're dropping to make room.</p>

      <div className="grid gap-2 sm:grid-cols-[1fr_180px_220px]">
        <div className="relative">
          <Search size={14} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-500" />
          <Input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search wrestlers…" className="pl-8" />
        </div>
        <Select value={weightClass} onChange={(e) => setWeightClass(e.target.value)}>
          <option value="">All weights</option>
          {WEIGHTS.map((w) => (
            <option key={w} value={w}>
              {w} lbs
            </option>
          ))}
        </Select>
        <Select value={teamId} onChange={(e) => setTeamId(e.target.value)}>
          <option value="">All teams</option>
          {teams.map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}
            </option>
          ))}
        </Select>
      </div>

      {isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-14 w-full" />
          ))}
        </div>
      ) : (
        <div className={isFetching ? 'space-y-2 opacity-60' : 'space-y-2'}>
          {wrestlers.map((w) => (
            <CompetitionCard
              key={w.canonical_wrestler_id}
              card={w}
              actions={
                <Button size="sm" disabled={!myRoster?.length} onClick={() => setClaimTarget(w)}>
                  <Plus size={14} /> Claim
                </Button>
              }
            />
          ))}
          {wrestlers.length === 0 && (
            <Card>
              <p className="p-6 text-center text-sm text-ink-500">No available wrestlers match those filters.</p>
            </Card>
          )}
        </div>
      )}

      <div className="flex items-center justify-center gap-2">
        <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
          Previous
        </Button>
        {data?.total_count != null && (
          <span className="text-xs text-ink-500">
            Page {page} of {Math.max(1, Math.ceil(data.total_count / (data.per_page || 50)))} · {data.total_count} available
          </span>
        )}
        <Button variant="secondary" size="sm" disabled={wrestlers.length < (data?.per_page ?? 50)} onClick={() => setPage((p) => p + 1)}>
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

import React from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, Plus, RefreshCw, Users } from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore } from '../lib/store'
import { Button, CardSkeleton, EmptyState } from '../components/ui'
import GroupCard from '../components/groups/GroupCard'
import JoinWithCode from '../components/groups/JoinWithCode'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

export default function Groups() {
  const user = useAuthStore((s) => s.user)
  const navigate = useNavigate()
  // my groups ride along on the dashboard payload
  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['dashboard'],
    queryFn: api.dashboard,
  })

  const groups = data?.groups ?? []

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="space-y-8 py-6">
      <motion.header variants={rise} className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl uppercase tracking-tight text-ink-100 sm:text-4xl">
            My <span className="text-gold-400">Groups</span>
          </h1>
          <p className="mt-1.5 text-sm text-ink-500">Bragging rights, settled on the mat.</p>
        </div>
        <Link to="/groups/new">
          <Button>
            <Plus size={16} /> Create group
          </Button>
        </Link>
      </motion.header>

      {isLoading ? (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <CardSkeleton key={i} />
          ))}
        </div>
      ) : isError ? (
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title="Groups failed to load"
          body={error?.message}
          action={
            <Button onClick={() => refetch()} loading={isRefetching}>
              <RefreshCw size={15} /> Try again
            </Button>
          }
        />
      ) : (
        <motion.div variants={stagger} className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {groups.map((g) => (
            <motion.div key={g.id} variants={rise}>
              <GroupCard group={g} mine={g.role === 'owner' || g.owner_id === user?.id} />
            </motion.div>
          ))}
          <motion.div variants={rise}>
            <JoinWithCode
              className="h-full"
              onJoined={(membership) => {
                const gid = membership?.group_id ?? membership?.group?.id
                if (gid) navigate(`/groups/${gid}`)
              }}
            />
          </motion.div>
          {groups.length === 0 && (
            <motion.div variants={rise} className="md:col-span-1 xl:col-span-2">
              <EmptyState
                icon={<Users size={26} />}
                title="You're not in any groups yet"
                body="Create one and invite your crew, or join with an invite code."
                action={
                  <Link to="/groups/new">
                    <Button>
                      <Plus size={16} /> Create your first group
                    </Button>
                  </Link>
                }
                className="h-full"
              />
            </motion.div>
          )}
        </motion.div>
      )}
    </motion.div>
  )
}
